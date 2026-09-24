import { useEffect, useState } from "react";

/** A minute: nothing on screen changes faster than the day does. */
const TICK_MS = 60_000;

/**
 * The current time, re-read on a timer.
 *
 * The day a hunt is started is read from it, so a window left open overnight rolls over
 * over on its own instead of freezing at whatever it said when it was opened.
 */
export function useNow(interval: number = TICK_MS): Date {
  const [now, setNow] = useState(() => new Date());

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), interval);
    return () => clearInterval(id);
  }, [interval]);

  return now;
}
