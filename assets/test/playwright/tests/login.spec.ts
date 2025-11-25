import { test, expect } from '@playwright/test';

test.use({ storageState: 'test/playwright/.auth.json' });

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
  });
});
