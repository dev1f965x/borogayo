import { answersFor, type Building, type Hunt, type Room } from "./hunt";
import { isFinished, type Score, score } from "./scoring";

export interface Ranked {
  room: Room;
  building: Building;
  score: Score;
  /** Its position among the finished rooms, or undefined while it is not one. */
  rank?: number;
}

/** Adjacent rooms of one building, shown under a single header. */
export interface Run {
  building: Building;
  entries: Ranked[];
}

/**
 * Every room of a hunt, best first.
 *
 * Unfinished rooms sort to the bottom and carry no rank: they are on the list because they
 * were visited, not because they are competing yet.
 */
export function ranked(hunt: Hunt): Ranked[] {
  const scored = hunt.rooms.flatMap((room) => {
    const building = hunt.buildings.find((each) => each.id === room.buildingId);
    if (!building) return [];
    return [{ room, building, score: score(hunt.criteria, answersFor(hunt, room)) }];
  });

  scored.sort(
    (one, other) =>
      (other.score.percent ?? -1) - (one.score.percent ?? -1) ||
      one.building.name.localeCompare(other.building.name, "ko") ||
      one.room.name.localeCompare(other.room.name, "ko"),
  );

  let place = 0;
  return scored.map((entry) => {
    if (!isFinished(entry.score)) return entry;
    place += 1;
    return { ...entry, rank: place };
  });
}

/**
 * Splits a ranked list into stretches of the same building.
 *
 * The order stays by score, so a building appears again whenever a room of another
 * building sits between two of its own. That repetition is the point: it is what shows
 * that one building's rooms are not all equally good.
 */
export function inRuns(board: readonly Ranked[]): Run[] {
  const runs: Run[] = [];

  for (const entry of board) {
    const last = runs.at(-1);
    if (last && last.building.id === entry.building.id) last.entries.push(entry);
    else runs.push({ building: entry.building, entries: [entry] });
  }

  return runs;
}
