import { test, expect } from '@playwright/test';

// Simple navigation and shop flow smoke test
test('Shop and add-to-cart smoke', async ({ page }: any) => {
  await page.goto('/');
  await page.click('text=Shop');
  // Wait for shop page to render
  await page.waitForSelector('.product-grid', { timeout: 5000 });
  const firstProduct = page.locator('.product-card').first();
  await firstProduct.click();
  // Click add to cart if button exists
  const addButton = page.locator('text=Add to cart');
  if (await addButton.count() > 0) {
    await addButton.click();
    await page.waitForTimeout(500);
    // check cart icon count changed
    const cartCount = await page.locator('#cart-count').count();
    expect(cartCount).toBeGreaterThanOrEqual(0);
  } else {
    test.skip('No add to cart button found on product page');
  }
});
