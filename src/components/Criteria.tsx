import { useState } from "react";
import {
  type Criterion,
  type Kind,
  ORDINARY_WEIGHT,
  type Scope,
  WEIGHTS,
  type Weight,
} from "../domain/criteria";
import type { Hunt } from "../domain/hunt";
import {
  CRITERIA_LABELS,
  KIND_HINTS,
  KIND_LABELS,
  SCOPE_HINTS,
  SCOPE_LABELS,
} from "../domain/labels";
import "./Criteria.css";

interface Props {
  hunt: Hunt;
  onAdd: (draft: Omit<Criterion, "id">) => void;
  onEdit: (criterionId: string, changes: Partial<Omit<Criterion, "id">>) => void;
  onMove: (criterionId: string, by: number) => void;
  onRemove: (criterionId: string) => void;
}

/** What gets decided before the first viewing, while judgement is still cold. */
export function Criteria({ hunt, onAdd, onEdit, onMove, onRemove }: Props) {
  const [name, setName] = useState("");
  const [scope, setScope] = useState<Scope>("room");
  const [kind, setKind] = useState<Kind>("scale");
  const [open, setOpen] = useState<string>();

  const add = (event: React.FormEvent) => {
    event.preventDefault();
    if (name.trim() === "") return;

    onAdd({ name: name.trim(), emoji: "", scope, kind, weight: ORDINARY_WEIGHT });
    setName("");
  };

  return (
    <div className="criteria">
      <p className="criteria__intro">{CRITERIA_LABELS.intro}</p>

      {hunt.criteria.length === 0 ? (
        <div className="criteria__empty">
          <p className="criteria__empty-title">{CRITERIA_LABELS.empty}</p>
          <p className="criteria__empty-detail">{CRITERIA_LABELS.emptyDetail}</p>
        </div>
      ) : (
        <ul className="criteria__list">
          {hunt.criteria.map((criterion, at) => (
            <li key={criterion.id} className="criteria__item">
              <div className="criteria__line">
                <span className="criteria__emoji" aria-hidden="true">
                  {criterion.emoji}
                </span>
                <button
                  type="button"
                  className="criteria__name"
                  aria-expanded={open === criterion.id}
                  onClick={() => setOpen(open === criterion.id ? undefined : criterion.id)}
                >
                  {criterion.name}
                  <span className="criteria__about">
                    {SCOPE_LABELS[criterion.scope]} · {KIND_LABELS[criterion.kind]}
                  </span>
                </button>

                <span className="criteria__weight">
                  <span className="visually-hidden">{CRITERIA_LABELS.weight}</span>
                  {criterion.weight}
                </span>

                <span className="criteria__order">
                  <button
                    type="button"
                    className="criteria__move"
                    aria-label={`${criterion.name} ${CRITERIA_LABELS.up}`}
                    disabled={at === 0}
                    onClick={() => onMove(criterion.id, -1)}
                  >
                    ↑
                  </button>
                  <button
                    type="button"
                    className="criteria__move"
                    aria-label={`${criterion.name} ${CRITERIA_LABELS.down}`}
                    disabled={at === hunt.criteria.length - 1}
                    onClick={() => onMove(criterion.id, 1)}
                  >
                    ↓
                  </button>
                </span>
              </div>

              {open === criterion.id && (
                <div className="criteria__editor">
                  <input
                    className="criteria__field"
                    value={criterion.name}
                    aria-label={CRITERIA_LABELS.namePlaceholder}
                    onChange={(event) => onEdit(criterion.id, { name: event.target.value })}
                  />

                  <p className="criteria__what">{CRITERIA_LABELS.weight}</p>
                  <fieldset className="criteria__weights">
                    <legend className="visually-hidden">{CRITERIA_LABELS.weight}</legend>
                    {WEIGHTS.map((weight) => (
                      <button
                        key={weight}
                        type="button"
                        className="criteria__pick"
                        aria-pressed={criterion.weight === weight}
                        aria-label={CRITERIA_LABELS.weightOf(weight)}
                        onClick={() => onEdit(criterion.id, { weight: weight as Weight })}
                      >
                        {weight}
                      </button>
                    ))}
                  </fieldset>

                  <p className="criteria__what">{CRITERIA_LABELS.scope}</p>
                  <fieldset className="criteria__row">
                    <legend className="visually-hidden">{CRITERIA_LABELS.scope}</legend>
                    {(["room", "building"] as const).map((each) => (
                      <button
                        key={each}
                        type="button"
                        className="criteria__pick criteria__pick--wide"
                        aria-pressed={criterion.scope === each}
                        onClick={() => onEdit(criterion.id, { scope: each })}
                      >
                        {SCOPE_LABELS[each]}
                      </button>
                    ))}
                  </fieldset>
                  <p className="criteria__hint">{SCOPE_HINTS[criterion.scope]}</p>

                  <p className="criteria__what">{CRITERIA_LABELS.kind}</p>
                  <fieldset className="criteria__row">
                    <legend className="visually-hidden">{CRITERIA_LABELS.kind}</legend>
                    {(["scale", "yesNo"] as const).map((each) => (
                      <button
                        key={each}
                        type="button"
                        className="criteria__pick criteria__pick--wide"
                        aria-pressed={criterion.kind === each}
                        onClick={() => onEdit(criterion.id, { kind: each })}
                      >
                        {KIND_LABELS[each]}
                      </button>
                    ))}
                  </fieldset>
                  <p className="criteria__hint">{KIND_HINTS[criterion.kind]}</p>

                  <button
                    type="button"
                    className="criteria__remove"
                    onClick={() => onRemove(criterion.id)}
                  >
                    {CRITERIA_LABELS.remove(criterion.name)}
                  </button>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}

      <form className="criteria__add" onSubmit={add}>
        <div className="criteria__row">
          {(["room", "building"] as const).map((each) => (
            <button
              key={each}
              type="button"
              className="criteria__pick criteria__pick--wide"
              aria-pressed={scope === each}
              onClick={() => setScope(each)}
            >
              {SCOPE_LABELS[each]}
            </button>
          ))}
          {(["scale", "yesNo"] as const).map((each) => (
            <button
              key={each}
              type="button"
              className="criteria__pick criteria__pick--wide"
              aria-pressed={kind === each}
              onClick={() => setKind(each)}
            >
              {KIND_LABELS[each]}
            </button>
          ))}
        </div>
        <div className="criteria__line">
          <input
            className="criteria__field"
            value={name}
            placeholder={CRITERIA_LABELS.namePlaceholder}
            aria-label={CRITERIA_LABELS.add}
            onChange={(event) => setName(event.target.value)}
          />
          <button type="submit" className="criteria__submit" disabled={name.trim() === ""}>
            {CRITERIA_LABELS.add}
          </button>
        </div>
      </form>

      <p className="criteria__keeps">{CRITERIA_LABELS.keepsForNext}</p>
    </div>
  );
}
