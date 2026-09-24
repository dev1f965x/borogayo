import { useState } from "react";
import type { Hunt } from "../domain/hunt";
import { describeDay, HUNT_LABELS } from "../domain/labels";
import "./HuntList.css";
import { HouseMark } from "./HouseMark";

interface Props {
  hunts: readonly Hunt[];
  onOpen: (id: string) => void;
  onStart: (name: string) => void;
  onRemove: (id: string) => void;
}

/** What one hunt has in it, said in a line. */
function about(hunt: Hunt): string {
  const places = HUNT_LABELS.places(hunt.buildings.length, hunt.rooms.length);
  if (hunt.startedOn === "") return places;
  return `${places} · ${HUNT_LABELS.startedOn(describeDay(hunt.startedOn))}`;
}

/** Every move this app has been used for. Most people have one; some come back. */
export function HuntList({ hunts, onOpen, onStart, onRemove }: Props) {
  const [name, setName] = useState("");

  const start = (event: React.FormEvent) => {
    event.preventDefault();
    onStart(name.trim() === "" ? HUNT_LABELS.namePlaceholder : name);
    setName("");
  };

  return (
    <div className="hunts">
      {hunts.length === 0 ? (
        <div className="hunts__empty">
          <HouseMark />
          <p className="hunts__empty-title">{HUNT_LABELS.empty}</p>
          <p className="hunts__empty-detail">{HUNT_LABELS.emptyDetail}</p>
        </div>
      ) : (
        <ul className="hunts__list">
          {hunts.map((hunt) => (
            <li key={hunt.id} className="hunts__item">
              <button
                type="button"
                className="hunts__open"
                aria-label={`${hunt.name}, ${about(hunt)}`}
                onClick={() => onOpen(hunt.id)}
              >
                <span className="hunts__name">{hunt.name}</span>
                <span className="hunts__about">{about(hunt)}</span>
              </button>
              <button
                type="button"
                className="hunts__remove"
                aria-label={HUNT_LABELS.remove(hunt.name)}
                onClick={() => onRemove(hunt.id)}
              >
                <svg viewBox="0 0 12 12" aria-hidden="true">
                  <path d="m3 3 6 6M9 3l-6 6" />
                </svg>
              </button>
            </li>
          ))}
        </ul>
      )}

      <form className="hunts__start" onSubmit={start}>
        <input
          className="hunts__field"
          value={name}
          placeholder={HUNT_LABELS.namePlaceholder}
          aria-label={HUNT_LABELS.start}
          onChange={(event) => setName(event.target.value)}
        />
        <button type="submit" className="hunts__submit">
          {HUNT_LABELS.start}
        </button>
      </form>
    </div>
  );
}
