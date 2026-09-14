/**
 * Timezone-correct conversion between clinic-local wall-clock time and UTC
 * instants (DATABASE_DESIGN.md "Time handling"). No dependency — uses `Intl`.
 *
 * Availability is stored as weekday + minutes-from-local-midnight; appointments
 * as `timestamptz`. Slot math must convert local windows to instants through
 * the clinic/location IANA zone, DST included.
 */

/** ms to add to a UTC instant to get the same wall-clock reading in `tz`. */
function tzOffsetMs(utcMs: number, tz: string): number {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const parts = dtf.formatToParts(new Date(utcMs));
  const f: Record<string, number> = {};
  for (const p of parts) if (p.type !== "literal") f[p.type] = Number(p.value);
  const asIfUtc = Date.UTC(
    f.year!,
    f.month! - 1,
    f.day!,
    (f.hour ?? 0) % 24,
    f.minute ?? 0,
    f.second ?? 0,
  );
  return asIfUtc - utcMs;
}

/** Local wall-clock (y, m[1-12], d, hour, minute) in `tz` → UTC Date. */
export function zonedWallTimeToUtc(
  y: number,
  m: number,
  d: number,
  hour: number,
  minute: number,
  tz: string,
): Date {
  const guess = Date.UTC(y, m - 1, d, hour, minute);
  let offset = tzOffsetMs(guess, tz);
  let result = guess - offset;
  // One correction pass for DST transition boundaries (date-fns-tz approach).
  const offset2 = tzOffsetMs(result, tz);
  if (offset2 !== offset) {
    offset = offset2;
    result = guess - offset;
  }
  return new Date(result);
}

export interface LocalDateParts {
  year: number;
  month: number; // 1-12
  day: number;
  hour: number;
  minute: number;
  weekdayIso: number; // 1 = Monday .. 7 = Sunday
}

const WEEKDAY_ISO: Record<string, number> = {
  Mon: 1,
  Tue: 2,
  Wed: 3,
  Thu: 4,
  Fri: 5,
  Sat: 6,
  Sun: 7,
};

/** How a UTC instant reads on the wall clock in `tz`. */
export function localPartsInZone(instant: Date, tz: string): LocalDateParts {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hour12: false,
    weekday: "short",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
  const f: Record<string, string> = {};
  for (const p of dtf.formatToParts(instant)) {
    if (p.type !== "literal") f[p.type] = p.value;
  }
  return {
    year: Number(f.year),
    month: Number(f.month),
    day: Number(f.day),
    hour: Number(f.hour) % 24,
    minute: Number(f.minute),
    weekdayIso: WEEKDAY_ISO[f.weekday ?? "Mon"] ?? 1,
  };
}

/** "YYYY-MM-DD" as seen in `tz`. */
export function localDateStringInZone(instant: Date, tz: string): string {
  const p = localPartsInZone(instant, tz);
  return `${p.year.toString().padStart(4, "0")}-${p.month
    .toString()
    .padStart(2, "0")}-${p.day.toString().padStart(2, "0")}`;
}

/** Parse "YYYY-MM-DD" → numeric parts (no tz). */
export function parseDateString(s: string): { y: number; m: number; d: number } {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(s);
  if (!m) throw new Error(`invalid date string: ${s}`);
  return { y: Number(m[1]), m: Number(m[2]), d: Number(m[3]) };
}

/** ISO weekday (1-7) for a plain calendar date. */
export function isoWeekday(y: number, m: number, d: number): number {
  const dow = new Date(Date.UTC(y, m - 1, d)).getUTCDay(); // 0=Sun..6=Sat
  return dow === 0 ? 7 : dow;
}

export function rangesOverlap(
  aStart: Date,
  aEnd: Date,
  bStart: Date,
  bEnd: Date,
): boolean {
  return aStart < bEnd && bStart < aEnd;
}
