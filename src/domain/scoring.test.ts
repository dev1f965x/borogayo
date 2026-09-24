import { describe, expect, it } from "vitest";
import type { Answer, Criterion, Weight } from "./criteria";
import { isFinished, score, stillOpen } from "./scoring";

function criterion(id: string, weight: Weight = 3): Criterion {
  return { id, name: id, emoji: "", scope: "room", kind: "scale", weight };
}

function answers(...pairs: [string, Answer][]): Record<string, Answer> {
  return Object.fromEntries(pairs);
}

describe("score", () => {
  it("gives no number while anything is still open", () => {
    const found = score([criterion("a"), criterion("b")], answers(["a", 10]));

    expect(found.percent).toBeUndefined();
    expect(found).toMatchObject({ answered: 1, open: 1, skipped: 0 });
  });

  it("puts the weighted answers on 0 to 100", () => {
    const found = score([criterion("a"), criterion("b")], answers(["a", 10], ["b", 0]));

    expect(found.percent).toBe(50);
  });

  it("lets a heavier criterion move the total further than a lighter one", () => {
    const heavy = score([criterion("a", 5), criterion("b", 1)], answers(["a", 10], ["b", 0]));
    const light = score([criterion("a", 1), criterion("b", 5)], answers(["a", 10], ["b", 0]));

    expect(heavy.percent).toBeGreaterThan(light.percent ?? 0);
  });

  it("leaves a skipped criterion out of both sides of the sum", () => {
    const found = score(
      [criterion("a"), criterion("b"), criterion("c")],
      answers(["a", 10], ["b", 5], ["c", "skipped"]),
    );

    expect(found.percent).toBe(75);
    expect(found).toMatchObject({ answered: 2, skipped: 1, open: 0, total: 3 });
  });

  it("gives no number when every criterion was skipped, having judged nothing", () => {
    const found = score([criterion("a")], answers(["a", "skipped"]));

    expect(found.percent).toBeUndefined();
    expect(found.open).toBe(0);
  });

  it("gives no number to a hunt with no criteria at all", () => {
    expect(score([], {}).percent).toBeUndefined();
  });

  it("ignores a value left behind by a criterion that was deleted", () => {
    const found = score([criterion("a")], answers(["a", 10], ["gone", 0]));

    expect(found.percent).toBe(100);
    expect(found.total).toBe(1);
  });
});

describe("isFinished", () => {
  it("is true only once there is a number to show", () => {
    expect(isFinished(score([criterion("a")], answers(["a", 7])))).toBe(true);
    expect(isFinished(score([criterion("a")], {}))).toBe(false);
  });
});

describe("stillOpen", () => {
  it("names what is left, counting a skip as answered", () => {
    const open = stillOpen(
      [criterion("a"), criterion("b"), criterion("c")],
      answers(["a", 4], ["b", "skipped"]),
    );

    expect(open.map((each) => each.id)).toEqual(["c"]);
  });
});
