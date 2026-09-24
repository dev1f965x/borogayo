import { useState } from "react";
import type { Hunt } from "../domain/hunt";
import { PLACE_LABELS } from "../domain/labels";
import "./AddPlace.css";

interface Props {
  hunt: Hunt;
  onAddBuilding: (name: string) => string;
  onAddRoom: (buildingId: string, name: string) => void;
}

/**
 * Where a place gets added, in the order it happens: you are shown into a building, and
 * then into a room in it. A building already visited is picked rather than typed again,
 * because that is what makes two rooms share its answers.
 */
export function AddPlace({ hunt, onAddBuilding, onAddRoom }: Props) {
  const [buildingId, setBuildingId] = useState<string>();
  const [building, setBuilding] = useState("");
  const [room, setRoom] = useState("");

  const chosen = hunt.buildings.find((each) => each.id === buildingId);

  const add = (event: React.FormEvent) => {
    event.preventDefault();
    if (room.trim() === "") return;

    const into = chosen?.id ?? onAddBuilding(building.trim() === "" ? room : building);
    onAddRoom(into, room);
    setRoom("");
    setBuilding("");
    setBuildingId(into);
  };

  return (
    <form className="add" onSubmit={add}>
      {hunt.buildings.length > 0 && (
        <fieldset className="add__buildings">
          <legend className="visually-hidden">{PLACE_LABELS.addBuilding}</legend>
          {hunt.buildings.map((each) => (
            <button
              key={each.id}
              type="button"
              className="add__building"
              aria-pressed={buildingId === each.id}
              onClick={() => setBuildingId(buildingId === each.id ? undefined : each.id)}
            >
              {each.name}
            </button>
          ))}
        </fieldset>
      )}

      {!chosen && (
        <input
          className="add__field"
          value={building}
          placeholder={PLACE_LABELS.buildingPlaceholder}
          aria-label={PLACE_LABELS.addBuilding}
          onChange={(event) => setBuilding(event.target.value)}
        />
      )}

      <div className="add__line">
        <input
          className="add__field"
          value={room}
          placeholder={PLACE_LABELS.roomPlaceholder}
          aria-label={PLACE_LABELS.addRoom}
          onChange={(event) => setRoom(event.target.value)}
        />
        <button type="submit" className="add__submit" disabled={room.trim() === ""}>
          {PLACE_LABELS.addRoom}
        </button>
      </div>
    </form>
  );
}
