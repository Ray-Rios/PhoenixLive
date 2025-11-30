import { chromium, FullConfig } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

export default async function globalSetup(config: FullConfig) {
  const user = process.env.TEST_USER || '';
  const pwd = process.env.TEST_PWD || '';
  const baseURL = process.env.TEST_URL || 'http://localhost:4000';
  const outPath = path.join(config.rootDir, 'test/playwright/.auth.json');

  if (!user || !pwd) {
    // No credentials provided; skip creating storage state
    return;
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const page = await context.newPage();

  await page.goto(`${baseURL}/login`);
  try {
    await page.fill('input[name="user[email]"]', user);
    await page.fill('input[name="user[password]"]', pwd);
    // click the form submit button (more resilient than a literal text locator)
    await page.waitForSelector('#auth-form button[type="submit"]', { timeout: 5000 });
    await page.click('#auth-form button[type="submit"]');
    await page.waitForLoadState('networkidle');
  } catch (e) {
    // ignore - best-effort login
  }

  // Playwright may follow redirects to a canonical host (e.g. phxlive.net) when the
  // application enforces a canonical domain. In those cases the cookies saved will
  // be tied to that canonical domain and won't be reused for tests hitting an
  // in-cluster hostname like `phoenix-web`.
  //
  // To make the saved storage state usable regardless of the canonical host,
  // copy all cookies returned by the session and re-set them against the
  // configured TEST_URL host (so subsequent tests against TEST_URL will have
  // the correct cookies). Also ensure the `secure` flag matches whether TEST_URL
  // uses HTTPS.
  try {
    const currentCookies = await context.cookies();
    const targetUrl = baseURL;
    const isHttps = baseURL.startsWith('https');

    // Only keep reasonable cookies (name + value) and map them to the TEST_URL origin.
    const rewritten = currentCookies
      .filter((c: any) => c && c.name && typeof c.value !== 'undefined')
      .map((c: any) => {
        // Build a minimal safe cookie object for addCookies — only include
        // defined fields. Playwright requires either url OR domain+path.
        const out: any = {
          name: c.name,
          value: c.value,
          url: targetUrl,
          path: c.path || '/',
        };

        if (typeof c.httpOnly !== 'undefined') out.httpOnly = c.httpOnly;
        if (typeof c.sameSite !== 'undefined') out.sameSite = c.sameSite;
        // ensure secure flag matches whether TEST_URL is HTTPS
        out.secure = !!isHttps;
        if (typeof c.expires === 'number' && c.expires > 0) out.expires = c.expires;

        return out;
      });

    if (rewritten.length) {
      // Re-set cookies on the context for the target TEST_URL host
      await context.addCookies(rewritten as any);
    }
  } catch (err) {
    // best-effort - don't fail setup if cookie rewriting fails
    // (we'll still persist whatever storage state we have)
    console.warn('cookie normalization failed:', err);
  }

  // Save storage state with cookies/localStorage/session
  await context.storageState({ path: outPath });
  await browser.close();
}
