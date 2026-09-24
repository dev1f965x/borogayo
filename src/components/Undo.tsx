import { useEffect } from "react";
import { PLACE_LABELS } from "../domain/labels";
import "./Undo.css";

interface Props {
  message: string;
  onUndo: () => void;
  onDismiss: () => void;
}

/** How long a change can be taken back before the offer goes away. */
const OFFERED_FOR_MS = 6000;

/** Everything here is tapped in a hurry, standing up, so every tap is takeable back. */
export function Undo({ message, onUndo, onDismiss }: Props) {
  useEffect(() => {
    const timer = setTimeout(onDismiss, OFFERED_FOR_MS);
    return () => clearTimeout(timer);
  }, [onDismiss]);

  return (
    <div className="undo" role="status">
      <p className="undo__message">{message}</p>
      <button type="button" className="undo__action" onClick={onUndo}>
        {PLACE_LABELS.undo}
      </button>
    </div>
  );
}
