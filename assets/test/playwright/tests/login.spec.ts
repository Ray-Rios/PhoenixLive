import { test, expect } from '@playwright/test';
import fs from 'fs';

// If a pre-created storage state exists, tests can optionally use it — but don't require it.
const storageFile = 'test/playwright/.auth.json';

test.describe('Auth/Login flow', () => {
  test('login with credentials when provided', async ({ page, baseURL }: any) => {
    const username = process.env.TEST_USER || '';
    const password = process.env.TEST_PWD || '';

    if (!username || !password) {
      test.skip('No test user credentials provided in env');
    }

    await page.goto('/login');
    await page.fill('input[name="user[email]"]', username);
    await page.fill('input[name="user[password]"]', password);
    // Use the auth form submit button, more robust than text-only selectors
    await page.waitForSelector('#auth-form button[type="submit"]', { timeout: 5000 });
    await page.click('#auth-form button[type="submit"]');

    // The app may redirect to a canonical host (e.g. https://phxlive.net). Accept either a
    // successful redirect away from the login path OR presence of a 'Logout' UI affordance.
    await Promise.race([
      page.waitForSelector('text=Logout', { timeout: 5000 }),
      page.waitForFunction(() => !window.location.pathname.includes('/login'), null, { timeout: 5000 }),
    ]);

    // Ensure we do not show a login error message
    await expect(page.locator('text=Invalid login')).toHaveCount(0);
    // After login, if storage wasn't present, store auth state for subsequent tests
    if (!fs.existsSync(storageFile)) {
      try {
        await page.context().storageState({ path: storageFile });
      } catch (err) {
        // best-effort: ignore when unable to write (e.g., readonly CI env), tests can still continue
        console.warn('Failed to write storage state:', err);
      }
    }
  });
});
