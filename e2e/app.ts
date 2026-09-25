import type { Page } from "@playwright/test";

/** Opens the app with hunts already stored, as someone coming back to one finds it. */
export async function openApp(page: Page, hunts: unknown[] = []) {
  // Seeded once, not on every navigation, so a reload sees what the app wrote.
  await page.addInitScript((hunts) => {
    if (window.localStorage.getItem("borogayo.hunts") !== null) return;
    window.localStorage.setItem("borogayo.hunts", JSON.stringify(hunts));
  }, hunts);
  await page.goto("/");
  await page.getByRole("heading", { level: 1 }).waitFor();
}

/** What the app has stored under one of its keys. */
export function stored(page: Page, key: "hunts" | "startingCriteria") {
  return page.evaluate(
    (key) => JSON.parse(window.localStorage.getItem(`borogayo.${key}`) ?? "null"),
    key,
  );
}

export const LIGHT = {
  id: "light",
  name: "채광",
  emoji: "☀️",
  scope: "room",
  kind: "scale",
  weight: 3,
};

export const TRANSIT = {
  id: "transit",
  name: "교통",
  emoji: "🚇",
  scope: "building",
  kind: "scale",
  weight: 3,
};

/** A hunt with two rooms in one building, which is the shape everything else is about. */
export function aHunt(over: Record<string, unknown> = {}) {
  return {
    id: "h",
    name: "가을 이사",
    startedOn: "2026-09-25",
    criteria: [LIGHT, TRANSIT],
    buildings: [{ id: "b", name: "햇살빌라", answers: {}, photos: [] }],
    rooms: [
      { id: "r1", buildingId: "b", name: "301호", answers: {}, photos: [] },
      { id: "r2", buildingId: "b", name: "302호", answers: {}, photos: [] },
    ],
    ...over,
  };
}
