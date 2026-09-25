import { type Answer, BEST } from "../domain/criteria";
import { answersFor, buildingOf, type Hunt } from "../domain/hunt";
import { BOARD_LABELS, COMPARE_LABELS, SCORE_LABELS } from "../domain/labels";
import { score } from "../domain/scoring";
import "./Compare.css";

interface Props {
  hunt: Hunt;
  roomIds: readonly string[];
  onClose: () => void;
}

/**
 * Two or three rooms compared criterion by criterion.
 *
 * The ranking gives the overall order; this gives the difference per criterion. An excluded
 * criterion is shown as excluded rather than left blank, since it is a difference between
 * the rooms (ADR 7).
 */
export function Compare({ hunt, roomIds, onClose }: Props) {
  const rooms = roomIds.flatMap((id) => {
    const room = hunt.rooms.find((each) => each.id === id);
    if (!room) return [];
    const building = buildingOf(hunt, room);
    return [{ room, building, answers: answersFor(hunt, room) }];
  });

  if (rooms.length < 2) {
    return (
      <div className="compare">
        <p className="compare__need">{COMPARE_LABELS.need}</p>
      </div>
    );
  }

  return (
    <div className="compare">
      <header className="compare__bar">
        <h2 className="compare__heading">{COMPARE_LABELS.heading}</h2>
        <button type="button" className="compare__close" onClick={onClose}>
          {BOARD_LABELS.stopComparing}
        </button>
      </header>

      <table className="compare__table">
        <thead>
          <tr>
            <th scope="col" className="compare__corner">
              <span className="visually-hidden">{COMPARE_LABELS.heading}</span>
            </th>
            {rooms.map(({ room, building }) => (
              <th key={room.id} scope="col" className="compare__room">
                <span className="compare__building">{building?.name}</span>
                <span className="compare__name">{room.name}</span>
              </th>
            ))}
          </tr>
        </thead>

        <tbody>
          {hunt.criteria.map((criterion) => {
            const values = rooms.map(({ answers }) => answers[criterion.id]);
            const best = bestOf(values);

            return (
              <tr key={criterion.id}>
                <th scope="row" className="compare__criterion">
                  <span aria-hidden="true">{criterion.emoji}</span> {criterion.name}
                </th>
                {values.map((value, at) => (
                  <td
                    key={rooms[at].room.id}
                    className="compare__cell"
                    data-best={best !== undefined && value === best}
                  >
                    {say(value, criterion.kind === "yesNo")}
                  </td>
                ))}
              </tr>
            );
          })}
        </tbody>

        <tfoot>
          <tr>
            <th scope="row" className="compare__criterion">
              {COMPARE_LABELS.total}
            </th>
            {rooms.map(({ room, answers }) => {
              const total = score(hunt.criteria, answers);
              return (
                <td key={room.id} className="compare__total">
                  {total.percent === undefined
                    ? BOARD_LABELS.noScore
                    : BOARD_LABELS.percent(total.percent)}
                </td>
              );
            })}
          </tr>
        </tfoot>
      </table>
    </div>
  );
}

/** The highest answer in a row, or nothing to mark when no two rooms can be told apart. */
function bestOf(values: readonly (Answer | undefined)[]): number | undefined {
  const numbers = values.filter((value): value is number => typeof value === "number");
  if (numbers.length < 2) return undefined;

  const best = Math.max(...numbers);
  return numbers.every((value) => value === best) ? undefined : best;
}

function say(value: Answer | undefined, yesNo: boolean): string {
  if (value === "skipped") return SCORE_LABELS.skip;
  if (value === undefined) return SCORE_LABELS.unanswered;
  if (yesNo) return value === BEST ? SCORE_LABELS.yes : SCORE_LABELS.no;
  return SCORE_LABELS.ofTen(value);
}
