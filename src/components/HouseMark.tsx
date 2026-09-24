import "./HouseMark.css";

/**
 * The app's mark, as it has always been: a house with a decision made about it.
 *
 * The name is beside it wherever it is drawn, so it is decoration and says nothing of its
 * own — otherwise every reading of the header says the name twice.
 */
export function HouseMark() {
  return (
    <svg className="mark" viewBox="0 0 40 40" aria-hidden="true">
      <path className="mark__walls" d="M8 18.5 20 8l12 10.5V31a2 2 0 0 1-2 2H10a2 2 0 0 1-2-2z" />
      <path className="mark__check" d="m15.5 22.5 3.4 3.4 6.1-6.6" />
    </svg>
  );
}
