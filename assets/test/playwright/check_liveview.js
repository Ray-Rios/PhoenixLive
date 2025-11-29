const { chromium } = require('playwright');

async function run() {
  const url = process.env.TEST_URL || 'http://localhost:4000';
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const consoleErrors = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });
  try {
    const response = await page.goto(url, { waitUntil: 'load', timeout: 30000 });
    if (!response) throw new Error('No response from server');
    console.log('PAGE STATUS:', response.status());
    // Wait briefly for LiveView to connect
    await page.waitForTimeout(1000);
    // Check for window.liveSocket
    const liveSocketExists = await page.evaluate(() => {
      try {
        return Boolean(window.liveSocket);
      } catch (e) {
        return false;
      }
    });
    console.log('liveSocket exists?', liveSocketExists);
    // Basic checks
    // Accept both 'data-phx-hook' and 'phx-hook' attributes (some elements may use either)
    const hooks = await page.$$eval('[data-phx-hook], [phx-hook]', (els) => els.map(e => e.getAttribute('data-phx-hook') || e.getAttribute('phx-hook')));
    console.log('Hooks present:', hooks.slice(0, 5));
    if (consoleErrors.length > 0) {
      console.error('Console errors:', consoleErrors.join('\n'));
      process.exit(2);
    }
    if (!liveSocketExists) {
      console.error('window.liveSocket not present — LiveView client may not have initialized');
      process.exit(3);
    }
    console.log('E2E smoke checks OK');
  } catch (e) {
    console.error('Playwright test failed:', e.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

run();
