import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: 'test/playwright',
  timeout: 30_000,
  expect: {
    timeout: 5000
  },
  fullyParallel: true,
  reporter: [['list'], ['github'], ['html', { outputFolder: 'assets/playwright-report' }]],
  use: {
    headless: true,
    viewport: { width: 1280, height: 720 },
    actionTimeout: 10_000,
    ignoreHTTPSErrors: true,
    baseURL: process.env.TEST_URL || 'http://localhost:4000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } }
  ],
  outputDir: 'assets/test-results',
  globalSetup: require.resolve('./test/playwright/global-setup.ts')
});
