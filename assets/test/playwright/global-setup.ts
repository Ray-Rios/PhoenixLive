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
    await page.click('text=Log in');
    await page.waitForLoadState('networkidle');
  } catch (e) {
    // ignore
  }

  // Save storage state with cookies/localStorage/session
  await context.storageState({ path: outPath });
  await browser.close();
}
