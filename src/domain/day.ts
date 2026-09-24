/** A calendar day, written the way it sorts: `2026-09-23`. */
export type Day = string;

export function dayOf(date: Date): Day {
  const year = date.getFullYear();
  const month = `${date.getMonth() + 1}`.padStart(2, "0");
  const day = `${date.getDate()}`.padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export function addDays(day: Day, days: number): Day {
  const date = new Date(`${day}T00:00:00`);
  date.setDate(date.getDate() + days);
  return dayOf(date);
}

/** Whole days from one day to the other: negative once the later one is past. */
export function daysBetween(from: Day, to: Day): number {
  const start = new Date(`${from}T00:00:00`).getTime();
  const end = new Date(`${to}T00:00:00`).getTime();
  return Math.round((end - start) / 86_400_000);
}
