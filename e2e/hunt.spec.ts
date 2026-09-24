import { expect, test } from "@playwright/test";
import { aHunt, openApp, stored } from "./app";

test("a first visit asks what the move is, and starts on the criteria", async ({ page }) => {
  await openApp(page);
  await expect(page.getByText("아직 시작한 게 없어요")).toBeVisible();

  await page.getByLabel("새로 시작하기").fill("가을 이사");
  await page.getByRole("button", { name: "새로 시작하기" }).click();

  await expect(
    page.getByText("보러 가기 전에 정해 두면, 현장에서는 점수만 매기면 돼요."),
  ).toBeVisible();
  await expect(page.getByText("교통")).toBeVisible();
  await expect.poll(() => stored(page, "hunts")).toMatchObject([{ name: "가을 이사" }]);
});

test("a building's answer is shared by every room in it", async ({ page }) => {
  await openApp(page, [aHunt()]);
  await page.getByRole("button", { name: /^가을 이사,/ }).click();

  await page.getByRole("button", { name: /301호/ }).click();
  await page.getByRole("group", { name: "교통" }).getByRole("button", { name: "8점" }).click();
  await page.getByRole("button", { name: "순위" }).first().click();

  await page.getByRole("button", { name: /302호/ }).click();
  await expect(
    page.getByRole("group", { name: "교통" }).getByRole("button", { name: "8점" }),
  ).toHaveAttribute("aria-pressed", "true");
});

test("a room is ranked once nothing is open, and 해당 없음 lets it finish", async ({ page }) => {
  await openApp(page, [aHunt()]);
  await page.getByRole("button", { name: /^가을 이사,/ }).click();
  await page.getByRole("button", { name: /301호/ }).click();

  await expect(page.getByText("2개 남았어요")).toBeVisible();

  await page.getByRole("group", { name: "채광" }).getByRole("button", { name: "10점" }).click();
  await page
    .getByRole("group", { name: "교통" })
    .getByRole("button", { name: "해당 없음" })
    .click();

  await expect(page.getByText("100%")).toBeVisible();
});

test("the ranking reorders as the rooms are scored, and holds two side by side", async ({
  page,
}) => {
  await openApp(page, [
    aHunt({
      buildings: [{ id: "b", name: "햇살빌라", answers: { transit: 6 }, photos: [] }],
      rooms: [
        { id: "r1", buildingId: "b", name: "301호", answers: { light: 2 }, photos: [] },
        { id: "r2", buildingId: "b", name: "302호", answers: { light: 10 }, photos: [] },
      ],
    }),
  ]);
  await page.getByRole("button", { name: /^가을 이사,/ }).click();

  await expect(page.locator(".board__name").first()).toHaveText("302호");

  await page.getByRole("button", { name: "나란히 보기" }).click();
  await page.getByRole("button", { name: /302호/ }).click();
  await page.getByRole("button", { name: /301호/ }).click();
  await page.getByRole("button", { name: "나란히 보기" }).click();

  const row = page.getByRole("row", { name: /채광/ });
  await expect(row.getByText("10점")).toHaveAttribute("data-best", "true");
});

test("a criterion added to a hunt becomes what the next one starts from", async ({ page }) => {
  await openApp(page, [aHunt()]);
  await page.getByRole("button", { name: /^가을 이사,/ }).click();
  await page.getByRole("button", { name: "볼 것 정하기" }).click();

  await page.getByLabel("항목 추가").fill("반려동물");
  await page.getByRole("button", { name: "항목 추가" }).click();

  await expect
    .poll(() => stored(page, "startingCriteria"))
    .toMatchObject([{ name: "채광" }, { name: "교통" }, { name: "반려동물" }]);
});
