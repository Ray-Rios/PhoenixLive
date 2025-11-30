import { test, expect } from '@playwright/test';

// Dead-simple smoke test: just verify the app boots and responds
test('app boots and homepage loads', async ({ page }) => {
  await page.goto('/');
  
  // Check basic page structure exists (adjust selector to match your actual homepage)
  await expect(page.locator('body')).toBeVisible();
  
  // Optional: check a key navigation element exists
  const hasNavigation = await page.locator('nav, header, [role="navigation"]').count();
  expect(hasNavigation).toBeGreaterThan(0);
});
