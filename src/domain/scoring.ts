import { type Answer, BEST, type Criterion } from "./criteria";

/** A room's total, and how much of it the total rests on. */
export interface Score {
  /** 0–100. Undefined while any criterion is unanswered (ADR 7). */
  percent?: number;
  /** Criteria given a value. */
  answered: number;
  /** Criteria excluded from this room's total. */
  skipped: number;
  /** Criteria with no answer, which withholds the percentage. */
  open: number;
  total: number;
}

/**
 * Weights the answers by criterion and expresses the result as 0–100.
 *
 * The percentage is withheld until nothing is open, since a partial total reads the same
 * as a complete one and the list is the ranking (ADR 7).
 *
 * A criterion excluded as 해당 없음 is dropped from both sides of the sum, so the result
 * covers what was judged rather than what was asked. A room with every criterion excluded
 * has nothing to average and is withheld as well.
 *
 * Yes/no answers are stored as 10 or 0, so one sum covers both kinds.
 */
export function score(criteria: readonly Criterion[], answers: Record<string, Answer>): Score {
  let weighted = 0;
  let mostPossible = 0;
  let answered = 0;
  let skipped = 0;
  let open = 0;

  // Iterating the criteria rather than the answers keeps values from deleted criteria out.
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

/** The criteria that are still unanswered. */
export function stillOpen(
  criteria: readonly Criterion[],
  answers: Record<string, Answer>,
): Criterion[] {
  return criteria.filter((criterion) => answers[criterion.id] === undefined);
}
