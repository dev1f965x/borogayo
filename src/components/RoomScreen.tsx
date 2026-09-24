import { useState } from "react";
import type { Answer } from "../domain/criteria";
import { answersFor, type Hunt, type Room } from "../domain/hunt";
import { BOARD_LABELS, PLACE_LABELS, SCORE_LABELS } from "../domain/labels";
import { score } from "../domain/scoring";
import type { Photos } from "../storage/photos";
import "./RoomScreen.css";
import { PhotoStrip } from "./PhotoStrip";
import { ScoreRow } from "./ScoreRow";

interface Props {
  hunt: Hunt;
  room: Room;
  photos: Photos;
  onAnswer: (criterionId: string, answer: Answer | undefined) => void;
  onEdit: (changes: { name?: string; memo?: string }) => void;
  onAddPhoto: (owner: { roomId?: string; buildingId?: string }, area: string, file: Blob) => void;
  onRemovePhoto: (photoId: string) => void;
  onRemove: () => void;
  onBack: () => void;
}

/** One place, scored where it stands. This is the screen the app exists for. */
export function RoomScreen({
  hunt,
  room,
  photos,
  onAnswer,
  onEdit,
  onAddPhoto,
  onRemovePhoto,
  onRemove,
  onBack,
}: Props) {
  const [memo, setMemo] = useState(room.memo ?? "");

  const building = hunt.buildings.find((each) => each.id === room.buildingId);
  const answers = answersFor(hunt, room);
  const total = score(hunt.criteria, answers);

  return (
    <div className="room">
      <header className="room__bar">
        <button type="button" className="room__back" onClick={onBack}>
          <svg viewBox="0 0 16 16" aria-hidden="true">
            <path d="M10 2.5 4.5 8l5.5 5.5" />
          </svg>
          {BOARD_LABELS.heading}
        </button>
        <span className="room__total">
          {total.percent === undefined
            ? SCORE_LABELS.open(total.open)
            : BOARD_LABELS.percent(total.percent)}
        </span>
      </header>

      <div className="room__head">
        <p className="room__building">{building?.name}</p>
        <input
          className="room__name"
          value={room.name}
          aria-label={PLACE_LABELS.addRoom}
          onChange={(event) => onEdit({ name: event.target.value })}
        />
      </div>

      <ul className="room__criteria">
        {hunt.criteria.map((criterion) => (
          <ScoreRow
            key={criterion.id}
            criterion={criterion}
            answer={answers[criterion.id]}
            shared={criterion.scope === "building"}
            onAnswer={(answer) => onAnswer(criterion.id, answer)}
          />
        ))}
      </ul>

      <label className="room__memo">
        <span className="room__label">{PLACE_LABELS.memo}</span>
        <textarea
          className="room__memo-field"
          value={memo}
          rows={3}
          placeholder={PLACE_LABELS.memoPlaceholder}
          onChange={(event) => setMemo(event.target.value)}
          onBlur={() => onEdit({ memo: memo.trim() })}
        />
      </label>

      <PhotoStrip
        photos={room.photos}
        areas="room"
        store={photos}
        onAdd={(area, file) => onAddPhoto({ roomId: room.id }, area, file)}
        onRemove={onRemovePhoto}
      />

      {building && (
        <PhotoStrip
          photos={building.photos}
          areas="building"
          store={photos}
          heading={building.name}
          onAdd={(area, file) => onAddPhoto({ buildingId: building.id }, area, file)}
          onRemove={onRemovePhoto}
        />
      )}

      <button type="button" className="room__remove" onClick={onRemove}>
        {PLACE_LABELS.removeRoom(room.name)}
      </button>
    </div>
  );
}
