import { type Answer, BEST, type Criterion } from "../domain/criteria";
import { SCOPE_LABELS, SCORE_LABELS } from "../domain/labels";
import "./ScoreRow.css";

interface Props {
  criterion: Criterion;
  answer: Answer | undefined;
  /** Said under a building criterion, because answering it here answers it everywhere. */
  shared: boolean;
  onAnswer: (answer: Answer | undefined) => void;
}

/** The steps a 0–10 criterion offers. Six fit across a phone at a tappable size. */
const STEPS = [0, 2, 4, 6, 8, 10];

/**
 * One criterion, answered in a single tap.
 *
 * The name is the group's legend rather than a separate heading, so it is announced once.
 * Tapping the current answer clears it, which is how a mis-tap is corrected.
 */
export function ScoreRow({ criterion, answer, shared, onAnswer }: Props) {
  const choose = (value: Answer) => onAnswer(answer === value ? undefined : value);

  return (
    <li className="score" data-answered={answer !== undefined}>
      <fieldset className="score__box">
        <legend className="score__what">
          <span className="score__emoji" aria-hidden="true">
            {criterion.emoji}
          </span>
          <span className="score__name">{criterion.name}</span>
          {shared && <span className="score__shared">{SCOPE_LABELS.building}</span>}
        </legend>

        <div className="score__choices">
          {criterion.kind === "scale"
            ? STEPS.map((value) => (
                <button
                  key={value}
                  type="button"
                  className="score__step"
                  aria-pressed={answer === value}
                  aria-label={SCORE_LABELS.ofTen(value)}
                  onClick={() => choose(value)}
                >
                  {value}
                </button>
              ))
            : [BEST, 0].map((value) => (
                <button
                  key={value}
                  type="button"
                  className="score__yesno"
                  aria-pressed={answer === value}
                  onClick={() => choose(value)}
                >
                  {value === BEST ? SCORE_LABELS.yes : SCORE_LABELS.no}
                </button>
              ))}

          <button
            type="button"
            className="score__skip"
            aria-pressed={answer === "skipped"}
            onClick={() => choose("skipped")}
          >
            {SCORE_LABELS.skip}
          </button>
        </div>
      </fieldset>
    </li>
  );
}
