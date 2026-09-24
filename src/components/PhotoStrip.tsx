import { useEffect, useRef, useState } from "react";
import type { Photo } from "../domain/hunt";
import { PHOTO_LABELS } from "../domain/labels";
import { shrink } from "../shell/photo";
import type { Photos } from "../storage/photos";
import "./PhotoStrip.css";

interface Props {
  photos: readonly Photo[];
  areas: "building" | "room";
  store: Photos;
  /** Named when the strip belongs to the building rather than the room being scored. */
  heading?: string;
  onAdd: (area: string, file: Blob) => void;
  onRemove: (photoId: string) => void;
}

/**
 * The photos of one place, taken on site and filed by which part they show.
 *
 * Each one is drawn onto a canvas and re-encoded on the way in, which is what resizes it —
 * and, in doing so, leaves every EXIF field behind, the recorded position above all
 * (ADR 6).
 */
export function PhotoStrip({ photos, areas, store, heading, onAdd, onRemove }: Props) {
  const [area, setArea] = useState(PHOTO_LABELS[`${areas}Areas`][0]);
  const camera = useRef<HTMLInputElement>(null);
  const places = PHOTO_LABELS[`${areas}Areas`];

  const take = async (file: File | undefined) => {
    const small = file ? await shrink(file) : undefined;
    if (small) onAdd(area, small);
  };

  return (
    <section className="strip">
      <div className="strip__head">
        <h3 className="strip__heading">{heading ?? PHOTO_LABELS.heading}</h3>
        <button type="button" className="strip__add" onClick={() => camera.current?.click()}>
          <svg viewBox="0 0 24 24" aria-hidden="true">
            <path d="M3.5 8h3.6l1.3-2h7.2l1.3 2h3.6v11h-17z" />
            <circle cx="12" cy="13" r="3.3" />
          </svg>
          {PHOTO_LABELS.add}
        </button>
        <input
          ref={camera}
          className="visually-hidden"
          type="file"
          accept="image/*"
          capture="environment"
          aria-label={PHOTO_LABELS.add}
          onChange={(event) => take(event.target.files?.[0])}
        />
      </div>

      <fieldset className="strip__areas">
        <legend className="visually-hidden">{PHOTO_LABELS.area}</legend>
        {places.map((each) => (
          <button
            key={each}
            type="button"
            className="strip__area"
            aria-pressed={area === each}
            onClick={() => setArea(each)}
          >
            {each}
          </button>
        ))}
      </fieldset>

      {photos.length === 0 ? (
        <p className="strip__none">{PHOTO_LABELS.stripped}</p>
      ) : (
        <ul className="strip__shots">
          {photos.map((photo) => (
            <li key={photo.id} className="strip__shot">
              <Shot store={store} id={photo.id} area={photo.area} />
              <button
                type="button"
                className="strip__remove"
                aria-label={`${photo.area} ${PHOTO_LABELS.remove}`}
                onClick={() => onRemove(photo.id)}
              >
                <svg viewBox="0 0 12 12" aria-hidden="true">
                  <path d="m3 3 6 6M9 3l-6 6" />
                </svg>
              </button>
              <span className="strip__label">{photo.area}</span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}

/** One photo, fetched from the picture store the first time it is on screen. */
function Shot({ store, id, area }: { store: Photos; id: string; area: string }) {
  const [url, setUrl] = useState<string>();

  useEffect(() => {
    let made: string | undefined;
    store.get(id).then((photo) => {
      if (!photo) return;
      made = URL.createObjectURL(photo);
      setUrl(made);
    });

    return () => {
      if (made) URL.revokeObjectURL(made);
    };
  }, [store, id]);

  return url ? (
    <img className="strip__image" src={url} alt={area} />
  ) : (
    <span className="strip__image" />
  );
}
