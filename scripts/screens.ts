import { mkdirSync, rmSync } from "node:fs";
import { chromium, type Page } from "@playwright/test";
import { createServer } from "vite";

/**
 * Photographs every state of the app, for design review and the README.
 *
 * The same page runs in a browser tab and in the Android app, so one set of shots covers
 * both, at a phone's width and at a desktop window's.
 *
 *   npm run screens        → screens/*.png
 */
const PHONE = { width: 420, height: 880 };
const DESKTOP = { width: 780, height: 820 };
const PORT = 1430;
const OUT = "screens";

interface Shot {
  name: string;
  hunts?: unknown[];
  act?: (page: Page) => Promise<void>;
  viewport?: { width: number; height: number };
}

const criteria = [
  { id: "c1", name: "교통", emoji: "🚇", scope: "building", kind: "scale", weight: 4 },
  { id: "c2", name: "주변 편의시설", emoji: "🏪", scope: "building", kind: "scale", weight: 3 },
  { id: "c3", name: "주차 가능", emoji: "🅿️", scope: "building", kind: "yesNo", weight: 2 },
  { id: "c4", name: "채광", emoji: "☀️", scope: "room", kind: "scale", weight: 4 },
  { id: "c5", name: "소음", emoji: "🔊", scope: "room", kind: "scale", weight: 4 },
  { id: "c6", name: "수압", emoji: "🚿", scope: "room", kind: "scale", weight: 3 },
  { id: "c7", name: "곰팡이·결로", emoji: "💧", scope: "room", kind: "scale", weight: 4 },
  { id: "c8", name: "가격", emoji: "💰", scope: "room", kind: "scale", weight: 5 },
];

const hunt = {
  id: "h",
  name: "가을 이사",
  startedOn: "2026-09-25",
  criteria,
  buildings: [
    { id: "b1", name: "햇살빌라", answers: { c1: 8, c2: 6, c3: 10 }, photos: [] },
    { id: "b2", name: "큰길 옆 오피스텔", answers: { c1: 10, c2: 10, c3: 0 }, photos: [] },
    { id: "b3", name: "언덕 위 주택", answers: { c1: 2, c2: 4, c3: 10 }, photos: [] },
  ],
  rooms: [
    {
      id: "r1",
      buildingId: "b1",
      name: "301호",
      answers: { c4: 10, c5: 8, c6: 8, c7: 10, c8: 8 },
      photos: [],
    },
    {
      id: "r2",
      buildingId: "b1",
      name: "201호",
      answers: { c4: 4, c5: 6, c6: 8, c7: 6, c8: 10 },
      photos: [],
    },
    {
      id: "r3",
      buildingId: "b2",
      name: "805호",
      answers: { c4: 8, c5: 2, c6: 10, c7: 8, c8: 2 },
      photos: [],
    },
    {
      id: "r4",
      buildingId: "b3",
      name: "2층 전체",
      answers: { c4: 10, c5: 10, c6: "skipped", c7: 4 },
      photos: [],
    },
  ],
};

const openHunt = (page: Page) => page.getByRole("button", { name: /^가을 이사,/ }).click();

const SHOTS: Shot[] = [
  { name: "start" },
  { name: "board", hunts: [hunt], act: openHunt },
  {
    name: "room",
    hunts: [hunt],
    act: async (page) => {
      await openHunt(page);
      await page.getByRole("button", { name: /2층 전체/ }).click();
    },
  },
  {
    name: "criteria",
    hunts: [hunt],
    act: async (page) => {
      await openHunt(page);
      await page.getByRole("button", { name: "볼 것 정하기" }).click();
    },
  },
  {
    name: "compare",
    hunts: [hunt],
    act: async (page) => {
      await openHunt(page);
      await page.getByRole("button", { name: "나란히 보기" }).click();
      await page.getByRole("button", { name: /301호/ }).click();
      await page.getByRole("button", { name: /805호/ }).click();
      await page.getByRole("button", { name: "나란히 보기" }).click();
    },
  },
  { name: "desktop-board", hunts: [hunt], act: openHunt, viewport: DESKTOP },
  {
    name: "desktop-compare",
    hunts: [hunt],
    act: async (page) => {
      await openHunt(page);
      await page.getByRole("button", { name: "나란히 보기" }).click();
      await page.getByRole("button", { name: /301호/ }).click();
      await page.getByRole("button", { name: /805호/ }).click();
      await page.getByRole("button", { name: /2층 전체/ }).click();
      await page.getByRole("button", { name: "나란히 보기" }).click();
    },
    viewport: DESKTOP,
  },
];

async function main() {
  rmSync(OUT, { recursive: true, force: true });
  mkdirSync(OUT, { recursive: true });
  const server = await createServer({
    server: { port: PORT, strictPort: true },
    logLevel: "error",
  });
  await server.listen();
  // Headless Chromium hides scrollbars, which the real window shows and gives room to.
  const browser = await chromium.launch({
    channel: "msedge",
    ignoreDefaultArgs: ["--hide-scrollbars"],
  });

  try {
    for (const shot of SHOTS) {
      const page = await browser.newPage({
        viewport: shot.viewport ?? PHONE,
        deviceScaleFactor: 2,
      });
      await page.addInitScript((hunts) => {
        window.localStorage.setItem("borogayo.hunts", JSON.stringify(hunts));
      }, shot.hunts ?? []);
      await page.goto(`http://localhost:${PORT}`);
      await page.getByRole("heading", { level: 1 }).waitFor();
      await shot.act?.(page);
      // Park the pointer clear of the page, so no hover state is photographed.
      await page.mouse.move(1, (shot.viewport ?? PHONE).height - 1);
      await page.waitForTimeout(300);
      await page.screenshot({ path: `${OUT}/${shot.name}.png` });
      await page.close();
      console.log(`${OUT}/${shot.name}.png`);
    }
  } finally {
    await browser.close();
    await server.close();
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
