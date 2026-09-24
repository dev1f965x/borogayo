import {
  type Answer,
  asWeight,
  type Criterion,
  isKind,
  isScope,
  ORDINARY_WEIGHT,
} from "../domain/criteria";
import type { Building, Hunt, Photo, Room } from "../domain/hunt";

const HUNTS = "borogayo.hunts";
const STARTING = "borogayo.startingCriteria";

/** Where a hunt lives: this device, and nowhere else (ADR 5). */
export interface Store {
  readHunts(): Hunt[];
  writeHunts(hunts: readonly Hunt[]): void;
  /** The criteria the next new hunt copies, as last edited. */
  readStartingCriteria(): Criterion[] | undefined;
  writeStartingCriteria(criteria: readonly Criterion[]): void;
}

export const localStore: Store = {
  readHunts: () => huntsFrom(read(HUNTS)),
  writeHunts: (hunts) => write(HUNTS, hunts),
  readStartingCriteria: () => {
    const stored = read(STARTING);
    return Array.isArray(stored) && stored.length > 0 ? criteriaFrom(stored) : undefined;
  },
  writeStartingCriteria: (criteria) => write(STARTING, criteria),
};

function read(key: string): unknown {
  try {
    return JSON.parse(localStorage.getItem(key) ?? "null");
  } catch {
    // Blocked or full storage is not worth an error screen; nothing found is honest.
    return null;
  }
}

function write(key: string, value: unknown) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {}
}

/**
 * Keeps only what this build understands. A value written by another version, or edited by
 * hand, costs its own entry rather than the whole screen.
 */
export function huntsFrom(stored: unknown): Hunt[] {
  if (!Array.isArray(stored)) return [];

  return stored.flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const { id, name, startedOn } = entry;
    if (typeof id !== "string" || typeof name !== "string" || name.trim() === "") return [];

    const buildings = buildingsFrom(entry.buildings);
    const known = new Set(buildings.map((building) => building.id));

    return [
      {
        id,
        name,
        startedOn: typeof startedOn === "string" ? startedOn : "",
        criteria: criteriaFrom(entry.criteria),
        buildings,
        // A room whose building did not survive has nothing to be scored against.
        rooms: roomsFrom(entry.rooms).filter((room) => known.has(room.buildingId)),
      },
    ];
  });
}

export function criteriaFrom(stored: unknown): Criterion[] {
  if (!Array.isArray(stored)) return [];

  return stored.flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const { id, name, emoji, scope, kind } = entry;
    if (typeof id !== "string" || typeof name !== "string" || name.trim() === "") return [];
    if (!isScope(scope) || !isKind(kind)) return [];

    return [
      {
        id,
        name,
        emoji: typeof emoji === "string" ? emoji : "",
        scope,
        kind,
        weight: entry.weight === undefined ? ORDINARY_WEIGHT : asWeight(entry.weight),
      },
    ];
  });
}

function buildingsFrom(stored: unknown): Building[] {
  if (!Array.isArray(stored)) return [];

  return stored.flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const { id, name } = entry;
    if (typeof id !== "string" || typeof name !== "string") return [];

    return [{ id, name, answers: answersFrom(entry.answers), photos: photosFrom(entry.photos) }];
  });
}

function roomsFrom(stored: unknown): Room[] {
  if (!Array.isArray(stored)) return [];

  return stored.flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const { id, buildingId, name, memo } = entry;
    if (typeof id !== "string" || typeof buildingId !== "string") return [];
    if (typeof name !== "string") return [];

    return [
      {
        id,
        buildingId,
        name,
        memo: typeof memo === "string" && memo !== "" ? memo : undefined,
        answers: answersFrom(entry.answers),
        photos: photosFrom(entry.photos),
      },
    ];
  });
}

function photosFrom(stored: unknown): Photo[] {
  if (!Array.isArray(stored)) return [];

  return stored.flatMap((entry) => {
    if (!isRecord(entry)) return [];
    const { id, area } = entry;
    if (typeof id !== "string") return [];

    return [{ id, area: typeof area === "string" ? area : "" }];
  });
}

function answersFrom(stored: unknown): Record<string, Answer> {
  if (!isRecord(stored)) return {};

  const answers: Record<string, Answer> = {};
  for (const [id, value] of Object.entries(stored)) {
    if (value === "skipped") answers[id] = "skipped";
    else if (typeof value === "number" && value >= 0) answers[id] = value;
  }
  return answers;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
