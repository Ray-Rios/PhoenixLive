import { test, expect } from '@playwright/test';

// This test validates that LiveView client is present and the websocket connection is established
test('LiveView client and websocket connection', async ({ page }: any) => {
  let wsOpen = false;
  page.on('websocket', ws => {
    ws.on('framereceived', frame => {
      // any frame indicates that websocket is working
    });
    wsOpen = true;
  });

  await page.goto('/');

  // wait briefly for LiveView behavior
  await page.waitForTimeout(1000);

  // Check global presence of liveSocket
  const liveSocketExists = await page.evaluate(() => typeof (window as any).liveSocket !== 'undefined');
  expect(liveSocketExists).toBeTruthy();

  // Check we opened a websocket - Playwright will fire 'websocket' events when created
  expect(wsOpen).toBeTruthy();

  // Check that a phx-hook element exists
  const hooks = await page.locator('[data-phx-hook]').count();
  expect(hooks).toBeGreaterThan(0);
});
