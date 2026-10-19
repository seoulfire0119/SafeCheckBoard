import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests/browser',
  timeout: 60000,
  workers: 1,
  use: { baseURL: 'http://127.0.0.1:5175', channel: 'chrome', headless: true, viewport: { width: 1440, height: 1000 } },
  webServer: {
    command: 'npm run dev -- --host 127.0.0.1 --port 5175 --strictPort',
    url: 'http://127.0.0.1:5175',
    env: { VITE_USE_EMULATOR: '1' },
    reuseExistingServer: false,
  },
});
