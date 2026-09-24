import { describe, expect, it } from "vitest";
import type { Answer, Criterion } from "./criteria";
import type { Building, Hunt, Room } from "./hunt";
import { inRuns, ranked } from "./ranking";

const light: Criterion = {
  id: "light",
  name: "채광",
  emoji: "☀️",
  scope: "room",
  kind: "scale",
  weight: 3,
};
const transit: Criterion = {
  id: "transit",
  name: "교통",
  emoji: "🚇",
  scope: "building",
  kind: "scale",
  weight: 3,
};

function building(id: string, answers: Record<string, Answer> = {}): Building {
  return { id, name: id, answers, photos: [] };
}

function room(id: string, buildingId: string, answers: Record<string, Answer> = {}): Room {
  return { id, buildingId, name: id, answers, photos: [] };
}

function hunt(buildings: Building[], rooms: Room[], criteria = [light, transit]): Hunt {
  return { id: "h", name: "이사", startedOn: "2026-09-25", criteria, buildings, rooms };
}

describe("ranked", () => {
  it("puts the better room first and numbers the finished ones", () => {
    const board = ranked(
      hunt(
        [building("가", { transit: 10 })],
        [room("좋은방", "가", { light: 10 }), room("어두운방", "가", { light: 2 })],
      ),
    );

    expect(board.map((each) => [each.room.id, each.rank])).toEqual([
      ["좋은방", 1],
      ["어두운방", 2],
    ]);
  });

  it("drops a room with anything still open below every finished room, unranked", () => {
    const board = ranked(
      hunt(
        [building("가", { transit: 10 })],
        [room("미완", "가", {}), room("최악", "가", { light: 0 })],
      ),
    );

    expect(board.map((each) => each.room.id)).toEqual(["최악", "미완"]);
    expect(board[0].rank).toBe(1);
    expect(board[1].rank).toBeUndefined();
  });

  it("scores every room of a building against the building's own answers", () => {
    const board = ranked(
      hunt(
        [building("역세권", { transit: 10 }), building("외곽", { transit: 0 })],
        [room("A", "역세권", { light: 5 }), room("B", "외곽", { light: 5 })],
      ),
    );

    expect(board.map((each) => each.room.id)).toEqual(["A", "B"]);
    expect(board[0].score.percent).toBeGreaterThan(board[1].score.percent ?? 0);
  });

  it("leaves out a room whose building is gone", () => {
    expect(ranked(hunt([], [room("떠돌이", "없는건물")]))).toEqual([]);
  });
});

describe("inRuns", () => {
  it("keeps adjacent rooms of one building under a single header", () => {
    const runs = inRuns(
      ranked(
        hunt(
          [building("가", { transit: 10 })],
          [room("1", "가", { light: 10 }), room("2", "가", { light: 8 })],
        ),
      ),
    );

    expect(runs).toHaveLength(1);
    expect(runs[0].entries.map((each) => each.room.id)).toEqual(["1", "2"]);
  });

  it("shows a building again when another building's room comes between its own", () => {
    const runs = inRuns(
      ranked(
        hunt(
          [building("가", { transit: 5 }), building("나", { transit: 5 })],
          [
            room("가-좋음", "가", { light: 10 }),
            room("나-중간", "나", { light: 6 }),
            room("가-나쁨", "가", { light: 1 }),
          ],
        ),
      ),
    );

    expect(runs.map((run) => run.building.id)).toEqual(["가", "나", "가"]);
  });
});
