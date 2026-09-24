import { defineConfig } from "@playwright/test";

const PORT = 1440;
const CI = Boolean(process.env.CI);

/**
 * End-to-end tests in a real Chromium: the same page the web build serves, and the one the
 * installed builds wrap. Locally they drive the installed Edge; CI installs Chromium. The
 * shells themselves are checked by hand before a release (ADR 6).
 */
export default defineConfig({
  testDir: "e2e",
  fullyParallel: true,
  forbidOnly: CI,
  retries: CI ? 1 : 0,
  reporter: CI ? "github" : "list",
  use: {
    baseURL: `http://localhost:${PORT}`,
    channel: CI ? undefined : "msedge",
    viewport: { width: 420, height: 820 },
    trace: "retain-on-failure",
  },
  webServer: {
    command: `npx vite --port ${PORT} --strictPort`,
    url: `http://localhost:${PORT}`,
    reuseExistingServer: !CI,
  },
});
