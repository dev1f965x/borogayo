import { type Answer, BEST, type Criterion } from "./criteria";

/** What a room comes to, and how much of it was actually judged. */
export interface Score {
  /** 0–100, and undefined while anything is still open (ADR 7). */
  percent?: number;
  /** Criteria given a value. */
  answered: number;
  /** Criteria deliberately left out of this room's total. */
  skipped: number;
  /** Criteria with no answer either way — what holds the percentage back. */
  open: number;
  total: number;
}

/**
 * Weights the answers by how much each criterion matters and puts them on 0–100.
 *
 * A number is only given once nothing is open, because a number on a half-judged place
 * cannot tell "what this place is worth" from "what has been judged so far" — and on a
 * screen where the list is the ranking, that ambiguity becomes a wrong decision.
 *
 * A criterion skipped as 해당 없음 leaves the sum on both sides, so the percentage is over
 * what was judged rather than over what was asked. A room where everything was skipped has
 * nothing to average and gets no number either.
 *
 * Yes/no answers are kept as 10 or 0, so both kinds go through the same sum.
 */
export function score(criteria: readonly Criterion[], answers: Record<string, Answer>): Score {
  let weighted = 0;
  let mostPossible = 0;
  let answered = 0;
  let skipped = 0;
  let open = 0;

  // Walked over the criteria, not the answers, so a value left behind by a deleted
  // criterion cannot creep back into a total.
  for (const criterion of criteria) {
    const answer = answers[criterion.id];

    if (answer === "skipped") {
      skipped += 1;
      continue;
    }
    if (typeof answer !== "number") {
      open += 1;
      continue;
    }

    weighted += answer * criterion.weight;
    mostPossible += BEST * criterion.weight;
    answered += 1;
  }

  const settled = open === 0 && mostPossible > 0;

  return {
    percent: settled ? (weighted / mostPossible) * 100 : undefined,
    answered,
    skipped,
    open,
    total: criteria.length,
  };
}

export function isFinished(score: Score): boolean {
  return score.percent !== undefined;
}

/** What still has to be answered before a room can be ranked. */
export function stillOpen(
  criteria: readonly Criterion[],
  answers: Record<string, Answer>,
): Criterion[] {
  return criteria.filter((criterion) => answers[criterion.id] === undefined);
}
