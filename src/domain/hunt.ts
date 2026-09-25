import type { Answer, Criterion } from "./criteria";

/** One move: its criteria, and every place scored against them. */
export interface Hunt {
  id: string;
  name: string;
  startedOn: string;
  criteria: Criterion[];
  buildings: Building[];
  rooms: Room[];
}

/** A photo of a place. The file is in the picture store; this is the reference (ADR 5). */
export interface Photo {
  id: string;
  /** Which part of the place it shows: 외관, 주방, and so on. */
  area: string;
}

/** A block of flats, holding only what its rooms have in common. */
export interface Building {
  id: string;
  name: string;
  /** Answers to the building-scoped criteria, shared by every room inside it. */
  answers: Record<string, Answer>;
  photos: Photo[];
}

/** A place that was visited. Rooms are what the ranking orders. */
export interface Room {
  id: string;
  buildingId: string;
  name: string;
  memo?: string;
  answers: Record<string, Answer>;
  photos: Photo[];
}

export function buildingOf(hunt: Hunt, room: Room): Building | undefined {
  return hunt.buildings.find((each) => each.id === room.buildingId);
}

/**
 * Every answer that applies to one room: its own, and its building's.
 *
 * A criterion's scope decides where its value is kept, so no value exists in two places.
 */
export function answersFor(hunt: Hunt, room: Room): Record<string, Answer> {
  const building = buildingOf(hunt, room);
  return { ...building?.answers, ...room.answers };
}
