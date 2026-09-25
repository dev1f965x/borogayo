import { useState } from "react";
import type { Hunt } from "../domain/hunt";
import { BOARD_LABELS, PLACE_LABELS, SCORE_LABELS } from "../domain/labels";
import { inRuns, ranked } from "../domain/ranking";
import "./Board.css";
import { AddPlace } from "./AddPlace";

interface Props {
  hunt: Hunt;
  onOpenRoom: (roomId: string) => void;
  onAddBuilding: (name: string) => string;
  onAddRoom: (buildingId: string, name: string) => void;
  onCompare: (roomIds: string[]) => void;
}

/** How many rooms can be held side by side before the columns stop being readable. */
const MOST_COMPARED = 3;

/** Every room, best first, with a building's adjacent rooms kept under one header. */
export function Board({ hunt, onOpenRoom, onAddBuilding, onAddRoom, onCompare }: Props) {
  const [picking, setPicking] = useState(false);
  const [picked, setPicked] = useState<string[]>([]);

  const board = ranked(hunt);
  const runs = inRuns(board);
  // A building with no rooms yet, mentioned once below the list.
  const unvisited = hunt.buildings.find(
    (building) => !hunt.rooms.some((room) => room.buildingId === building.id),
  );

  const pick = (roomId: string) => {
    setPicked((chosen) =>
      chosen.includes(roomId)
        ? chosen.filter((each) => each !== roomId)
        : chosen.length < MOST_COMPARED
          ? [...chosen, roomId]
          : chosen,
    );
  };

  const stop = () => {
    setPicking(false);
    setPicked([]);
  };

  if (hunt.rooms.length === 0) {
    return (
      <div className="board">
        <div className="board__empty">
          <p className="board__empty-title">{BOARD_LABELS.empty}</p>
          <p className="board__empty-detail">{BOARD_LABELS.emptyDetail}</p>
        </div>
        <AddPlace hunt={hunt} onAddBuilding={onAddBuilding} onAddRoom={onAddRoom} />
      </div>
    );
  }

  return (
    <div className="board">
      <div className="board__tools">
        {picking ? (
          <>
            <span className="board__picking">
              {picked.length < 2 ? BOARD_LABELS.comparePick : BOARD_LABELS.comparing(picked.length)}
            </span>
            <button type="button" className="board__quiet" onClick={stop}>
              {BOARD_LABELS.stopComparing}
            </button>
            <button
              type="button"
              className="board__go"
              disabled={picked.length < 2}
              onClick={() => onCompare(picked)}
            >
              {BOARD_LABELS.compare}
            </button>
          </>
        ) : (
          <button
            type="button"
            className="board__quiet"
            disabled={board.length < 2}
            onClick={() => setPicking(true)}
          >
            {BOARD_LABELS.compare}
          </button>
        )}
      </div>

      {runs.map((run) => (
        <section className="board__run" key={run.entries[0].room.id}>
          <h3 className="board__building">{run.building.name}</h3>
          <ul className="board__rooms">
            {run.entries.map(({ room, score, rank }) => {
              const chosen = picked.includes(room.id);
              return (
                <li key={room.id}>
                  <button
                    type="button"
                    className="board__room"
                    data-finished={score.percent !== undefined}
                    data-chosen={chosen}
                    aria-pressed={picking ? chosen : undefined}
                    onClick={() => (picking ? pick(room.id) : onOpenRoom(room.id))}
                  >
                    <span className="board__rank">{rank ?? BOARD_LABELS.noScore}</span>
                    <span className="board__what">
                      <span className="board__name">{room.name}</span>
                      <span className="board__state">
                        {score.percent === undefined
                          ? SCORE_LABELS.open(score.open)
                          : score.skipped > 0
                            ? `${SCORE_LABELS.skip} ${score.skipped}`
                            : SCORE_LABELS.done}
                      </span>
                    </span>
                    <span className="board__percent">
                      {score.percent === undefined
                        ? BOARD_LABELS.noScore
                        : BOARD_LABELS.percent(score.percent)}
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      ))}

      {!picking && <AddPlace hunt={hunt} onAddBuilding={onAddBuilding} onAddRoom={onAddRoom} />}
      {unvisited && <p className="board__note">{PLACE_LABELS.buildingOnly(unvisited.name)}</p>}
    </div>
  );
}
