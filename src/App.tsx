import { useState } from "react";
import "./design/base.css";
import "./App.css";
import { Board } from "./components/Board";
import { Compare } from "./components/Compare";
import { Criteria } from "./components/Criteria";
import { HouseMark } from "./components/HouseMark";
import { HuntList } from "./components/HuntList";
import { RoomScreen } from "./components/RoomScreen";
import { Undo } from "./components/Undo";
import { dayOf } from "./domain/day";
import {
  APP_NAME,
  BOARD_LABELS,
  CRITERIA_LABELS,
  HUNT_LABELS,
  PHOTO_LABELS,
  PLACE_LABELS,
} from "./domain/labels";
import { useNow } from "./shell/clock";
import { useHunts } from "./state/useHunts";
import type { Photos } from "./storage/photos";
import type { Store } from "./storage/store";

export interface AppProps {
  store: Store;
  photos: Photos;
  /** Fixed by tests; the app reads a clock that rolls the day over on its own. */
  now?: Date;
}

/** Where in the app someone is. A hunt is opened, a room is entered, two are held up. */
type Where =
  | { at: "hunts" }
  | { at: "hunt"; tab: "board" | "criteria" }
  | { at: "room"; roomId: string }
  | { at: "compare"; roomIds: string[] };

export default function App({ store, photos, now }: AppProps) {
  const ticking = useNow();
  const hunts = useHunts(store, photos, dayOf(now ?? ticking));
  const [where, setWhere] = useState<Where>({ at: "hunts" });

  const open = hunts.open;
  const room =
    where.at === "room" ? open?.rooms.find((each) => each.id === where.roomId) : undefined;

  const toBoard = () => setWhere({ at: "hunt", tab: "board" });

  return (
    <div className="app">
      <header className="app__bar">
        <button
          type="button"
          className="app__home"
          onClick={() => {
            hunts.openHunt(undefined);
            setWhere({ at: "hunts" });
          }}
        >
          <HouseMark />
          <h1 className="app__name">{open?.name ?? APP_NAME}</h1>
        </button>
        <span className="app__version">v{__APP_VERSION__}</span>
      </header>

      {where.at === "hunt" && open && (
        <nav className="app__tabs" aria-label={HUNT_LABELS.heading}>
          <button
            type="button"
            className="app__tab"
            aria-pressed={where.tab === "board"}
            onClick={toBoard}
          >
            {BOARD_LABELS.heading}
          </button>
          <button
            type="button"
            className="app__tab"
            aria-pressed={where.tab === "criteria"}
            onClick={() => setWhere({ at: "hunt", tab: "criteria" })}
          >
            {CRITERIA_LABELS.heading}
          </button>
        </nav>
      )}

      <main className="app__main">
        {where.at === "hunts" && (
          <HuntList
            hunts={hunts.hunts}
            onOpen={(id) => {
              hunts.openHunt(id);
              setWhere({ at: "hunt", tab: hasCriteria(hunts.hunts, id) ? "board" : "criteria" });
            }}
            onStart={(name) => {
              hunts.start(name);
              setWhere({ at: "hunt", tab: "criteria" });
            }}
            onRemove={(id) =>
              hunts.removeHunt(
                id,
                HUNT_LABELS.removed(hunts.hunts.find((hunt) => hunt.id === id)?.name ?? ""),
              )
            }
          />
        )}

        {where.at === "hunt" && open && where.tab === "board" && (
          <Board
            hunt={open}
            onOpenRoom={(roomId) => setWhere({ at: "room", roomId })}
            onAddBuilding={(name) => hunts.addBuilding(open.id, name)}
            onAddRoom={(buildingId, name) => hunts.addRoom(open.id, buildingId, name)}
            onCompare={(roomIds) => setWhere({ at: "compare", roomIds })}
          />
        )}

        {where.at === "hunt" && open && where.tab === "criteria" && (
          <Criteria
            hunt={open}
            onAdd={(draft) => hunts.addCriterion(open.id, draft)}
            onEdit={(criterionId, changes) => hunts.editCriterion(open.id, criterionId, changes)}
            onMove={(criterionId, by) => hunts.moveCriterion(open.id, criterionId, by)}
            onRemove={(criterionId) =>
              hunts.removeCriterion(
                open.id,
                criterionId,
                CRITERIA_LABELS.removed(
                  open.criteria.find((each) => each.id === criterionId)?.name ?? "",
                ),
              )
            }
          />
        )}

        {where.at === "room" && open && room && (
          <RoomScreen
            hunt={open}
            room={room}
            photos={photos}
            onAnswer={(criterionId, answer) => hunts.answer(open.id, room.id, criterionId, answer)}
            onEdit={(changes) => hunts.editRoom(open.id, room.id, changes)}
            onAddPhoto={(owner, area, file) => hunts.addPhoto(open.id, owner, area, file)}
            onRemovePhoto={(photoId) => hunts.removePhoto(open.id, photoId, PHOTO_LABELS.removed)}
            onRemove={() => {
              hunts.removeRoom(open.id, room.id, PLACE_LABELS.removedRoom(room.name));
              toBoard();
            }}
            onBack={toBoard}
          />
        )}

        {where.at === "compare" && open && (
          <Compare hunt={open} roomIds={where.roomIds} onClose={toBoard} />
        )}
      </main>

      {hunts.undoing && (
        <Undo message={hunts.undoing} onUndo={hunts.undo} onDismiss={hunts.forgetUndo} />
      )}
    </div>
  );
}

/** A hunt with nothing to score against opens on its criteria, which is where it starts. */
function hasCriteria(hunts: readonly { id: string; criteria: unknown[] }[], id: string): boolean {
  return (hunts.find((hunt) => hunt.id === id)?.criteria.length ?? 0) > 0;
}
