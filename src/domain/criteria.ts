/**
 * Whether a criterion is judged once per building or once per room.
 *
 * Transit and parking are the same for every unit in a building; asking for them again in
 * each room is repetitive, and the answers drift apart when it is asked twice.
 */
export type Scope = "building" | "room";

/**
 * How a criterion is answered.
 *
 * - `scale`: 0–10, in halves
 * - `yesNo`: yes or no, kept as 10 or 0 so one weighted sum covers both
 */
export type Kind = "scale" | "yesNo";

/** The top of both scales, which is what makes a single weighted formula possible. */
export const BEST = 10;

/** How much a criterion is allowed to matter, relative to the others. */
export const WEIGHTS = [1, 2, 3, 4, 5] as const;
export type Weight = (typeof WEIGHTS)[number];

export const ORDINARY_WEIGHT: Weight = 3;

export interface Criterion {
  id: string;
  name: string;
  emoji: string;
  scope: Scope;
  kind: Kind;
  weight: Weight;
}

/** What a room's answer to one criterion can be: a number, deliberately skipped, or open. */
export type Answer = number | "skipped";

/** The criteria a new hunt starts from, until the person edits their own set. */
export const STARTING_CRITERIA: readonly Omit<Criterion, "id">[] = [
  { name: "교통", emoji: "🚇", scope: "building", kind: "scale", weight: 4 },
  { name: "주변 편의시설", emoji: "🏪", scope: "building", kind: "scale", weight: 3 },
  { name: "건물 관리 상태", emoji: "🧹", scope: "building", kind: "scale", weight: 3 },
  { name: "주차 가능", emoji: "🅿️", scope: "building", kind: "yesNo", weight: 2 },
  { name: "엘리베이터", emoji: "🛗", scope: "building", kind: "yesNo", weight: 2 },
  { name: "채광", emoji: "☀️", scope: "room", kind: "scale", weight: 4 },
  { name: "소음", emoji: "🔊", scope: "room", kind: "scale", weight: 4 },
  { name: "수압", emoji: "🚿", scope: "room", kind: "scale", weight: 3 },
  { name: "곰팡이·결로", emoji: "💧", scope: "room", kind: "scale", weight: 4 },
  { name: "방 크기", emoji: "📐", scope: "room", kind: "scale", weight: 3 },
  { name: "가격", emoji: "💰", scope: "room", kind: "scale", weight: 5 },
  { name: "풀옵션", emoji: "🛋️", scope: "room", kind: "yesNo", weight: 2 },
];

export function isScope(value: unknown): value is Scope {
  return value === "building" || value === "room";
}

export function isKind(value: unknown): value is Kind {
  return value === "scale" || value === "yesNo";
}

export function asWeight(value: unknown): Weight {
  const rounded = Math.round(Number(value));
  return (WEIGHTS as readonly number[]).includes(rounded) ? (rounded as Weight) : ORDINARY_WEIGHT;
}
