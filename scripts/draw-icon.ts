import { mkdirSync } from "node:fs";
import { chromium } from "@playwright/test";

/**
 * Draws the app's icon, the same house the window shows, at the size Tauri's generator
 * expects. `npx tauri icon` cuts it into every format.
 *
 *   npm run art:icon   → src-tauri/icons/source.png
 */
const SIZE = 1024;
const OUT = "src-tauri/icons";

const mark = `
<!doctype html>
<html>
  <body style="margin:0">
    <svg xmlns="http://www.w3.org/2000/svg" width="${SIZE}" height="${SIZE}" viewBox="0 0 40 40">
      <defs>
        <linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stop-color="#6f5da5" />
          <stop offset="1" stop-color="#4c3e77" />
        </linearGradient>
      </defs>
      <rect width="40" height="40" rx="9" fill="url(#dusk)" />
      <path d="M7.5 18.8 20 7.6l12.5 11.2V31a2.6 2.6 0 0 1-2.6 2.6H10.1A2.6 2.6 0 0 1 7.5 31z" fill="#ffffff" />
      <path d="m15.2 22.8 3.6 3.6 6.4-7" fill="none" stroke="#5b4b8a" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round" />
    </svg>
  </body>
</html>`;

mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ channel: "msedge" });
const page = await browser.newPage({ viewport: { width: SIZE, height: SIZE } });
await page.setContent(mark);
await page.locator("svg").screenshot({ path: `${OUT}/source.png`, omitBackground: true });
await browser.close();

console.log(`${OUT}/source.png`);
