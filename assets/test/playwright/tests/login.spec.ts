import { test, expect } from '@playwright/test';
import fs from 'fs';

// If a pre-created storage state exists, reuse it. If not, tests will perform interactive login and save the storage state.
const storageFile = 'test/playwright/.auth.json';
if (fs.existsSync(storageFile)) {
  test.use({ storageState: storageFile });
}

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
    await page.click('text=Log in');

    await expect(page).toHaveURL(/\/(|profile|dashboard|)$/i, { timeout: 5000 });
    // Ensure we do not show error for wrong credentials
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
