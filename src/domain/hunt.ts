import type { Answer, Criterion } from "./criteria";

/** One move: the criteria decided up front, and every place looked at under them. */
export interface Hunt {
  id: string;
  name: string;
  startedOn: string;
  criteria: Criterion[];
  buildings: Building[];
  rooms: Room[];
}

/** A photo of a place. The file is in the picture store; only this points at it (ADR 5). */
export interface Photo {
  id: string;
  /** Which part of the place it shows: 외관, 주방, and so on. */
  area: string;
}

/** A block of flats. It exists to hold what its rooms have in common, and nothing else. */
export interface Building {
  id: string;
  name: string;
  /** Answers to the building-scoped criteria, shared by every room inside it. */
  answers: Record<string, Answer>;
  photos: Photo[];
}

/** A place actually walked through. This is the thing that gets ranked. */
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

export function roomsIn(hunt: Hunt, buildingId: string): Room[] {
  return hunt.rooms.filter((room) => room.buildingId === buildingId);
}

/**
 * Every answer that bears on one room: its own, plus the building's.
 *
 * Which criterion a value belongs to decides where it is kept, so nothing can be answered
 * in two places and disagree with itself.
 */
export function answersFor(hunt: Hunt, room: Room): Record<string, Answer> {
  const building = buildingOf(hunt, room);
  return { ...building?.answers, ...room.answers };
}

/** A criterion is answered on the building or on the room, never on both. */
export function holderOf(criterion: Criterion, room: Room, building: Building) {
  return criterion.scope === "building" ? building : room;
}
