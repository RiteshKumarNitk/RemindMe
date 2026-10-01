import { AppError } from "@/lib/errors.js";
import { localPartsInZone, zonedWallTimeToUtc } from "@/lib/time.js";

/**
 * The per-doctor same-day token window (TOKEN_BOOKING_ASSESSMENT.md §2/§3).
 *
 * Everything here is PURE and derives "today" from the clinic's IANA zone — never
 * from a date sent by a client, never from the caller's device clock. The window
 * is stored as minutes-from-clinic-local-midnight, the same convention as
 * `AvailabilityRule`, so it survives DST correctly (see `zonedWallTimeToUtc`).
 *
 * There is NO hardcoded 7:00 AM anywhere: the defaults live in the schema and
 * are per-doctor, overridable by the doctor or a clinic admin.
 */

/** Minute-counts a doctor may configure. Bounds are generous but bounded so a
 *  mis-typed form can't produce an unservable window (e.g. 09:61). */
export const MIN_TOKEN_MINUTE = 0;
export const MAX_TOKEN_MINUTE = 24 * 60 - 1;

export interface TokenWindowConfig {
  bookingMode: "SCHEDULED" | "SAME_DAY_TOKEN" | "BOTH";
  tokenOpensMinute: number;
  tokenClosesMinute: number;
  queueStartMinute: number;
  maxDailyTokens: number;
  /** Doctor's consultation length, used to build the token appointment slot. */
  consultationDurationMin: number;
}

export type TokenWindowStatus = "OPEN" | "NOT_YET_OPEN" | "CLOSED" | "UNAVAILABLE";

export interface TokenWindow {
  status: TokenWindowStatus;
  /** True only for the two states in which a patient may book right now. */
  bookable: boolean;
  /** Clinic-local calendar day the window refers to, "YYYY-MM-DD". */
  date: string;
  timezone: string;
  /** Human-readable local times, pre-formatted so callers never re-derive them. */
  opensAt: string;
  closesAt: string;
  queueStartAt: string;
  /** UTC instants, for callers that need to compare against `new Date()`. */
  opensAtUtc: string;
  closesAtUtc: string;
  queueStartUtc: string;
  /** Why booking is refused, when `bookable` is false. */
  reason: string | null;
  errorCode:
    | "TOKEN_BOOKING_NOT_OPEN"
    | "TOKEN_BOOKING_CLOSED"
    | "TOKEN_BOOKING_UNAVAILABLE"
    | "TOKEN_LIMIT_REACHED"
    | null;
}

/** Minutes -> "HH:MM" (24h, clinic-local, no timezone maths). */
export function formatMinuteOfDay(minute: number): string {
  const m = ((minute % 1440) + 1440) % 1440;
  return `${Math.floor(m / 60).toString().padStart(2, "0")}:${(m % 60)
    .toString()
    .padStart(2, "0")}`;
}

function localMinuteOfDay(parts: { hour: number; minute: number }): number {
  return parts.hour * 60 + parts.minute;
}

/**
 * Validate a doctor-configured window. Called when the config is saved, so a
 * doctor can never persist a window that is impossible to serve (closes before
 * it opens, or queue start outside the booking window).
 */
export function assertValidTokenWindow(cfg: {
  tokenOpensMinute: number;
  tokenClosesMinute: number;
  queueStartMinute: number;
  maxDailyTokens: number;
}): void {
  const { tokenOpensMinute: o, tokenClosesMinute: c, queueStartMinute: q } = cfg;
  for (const [name, v] of [
    ["tokenOpensMinute", o],
    ["tokenClosesMinute", c],
    ["queueStartMinute", q],
  ] as const) {
    if (!Number.isInteger(v) || v < MIN_TOKEN_MINUTE || v > MAX_TOKEN_MINUTE) {
      throw new AppError("VALIDATION_FAILED", `${name} must be a whole minute within a day.`);
    }
  }
  if (!Number.isInteger(cfg.maxDailyTokens) || cfg.maxDailyTokens < 1 || cfg.maxDailyTokens > 1000) {
    throw new AppError("VALIDATION_FAILED", "maxDailyTokens must be between 1 and 1000.");
  }
  if (c <= o) {
    throw new AppError(
      "VALIDATION_FAILED",
      "Token booking must close after it opens (same-day only — the window cannot run past midnight).",
    );
  }
  if (q < o || q > c) {
    throw new AppError(
      "VALIDATION_FAILED",
      "Queue start must fall inside the token booking window.",
    );
  }
}

export function allowsTokenBooking(mode: TokenWindowConfig["bookingMode"]): boolean {
  return mode === "SAME_DAY_TOKEN" || mode === "BOTH";
}

/**
 * Compute the live state of a doctor's token window.
 *
 * `now` is injectable purely so tests can pin the clock; production callers pass
 * nothing and get the server's own time. "Today" is always resolved in `tz`.
 */
export function computeTokenWindow(
  cfg: TokenWindowConfig,
  timezone: string,
  now: Date = new Date(),
  /** Tokens already issued for this (doctor, day) — for the daily cap. */
  tokensIssued = 0,
): TokenWindow {
  const local = localPartsInZone(now, timezone);
  const date = `${local.year.toString().padStart(4, "0")}-${local.month
    .toString()
    .padStart(2, "0")}-${local.day.toString().padStart(2, "0")}`;

  // Build the day's instants from clinic-local wall time, DST-aware.
  const opensAt = zonedWallTimeToUtc(
    local.year,
    local.month,
    local.day,
    Math.floor(cfg.tokenOpensMinute / 60),
    cfg.tokenOpensMinute % 60,
    timezone,
  );
  const closesAt = zonedWallTimeToUtc(
    local.year,
    local.month,
    local.day,
    Math.floor(cfg.tokenClosesMinute / 60),
    cfg.tokenClosesMinute % 60,
    timezone,
  );
  const queueStart = zonedWallTimeToUtc(
    local.year,
    local.month,
    local.day,
    Math.floor(cfg.queueStartMinute / 60),
    cfg.queueStartMinute % 60,
    timezone,
  );

  const base = {
    date,
    timezone,
    opensAt: formatMinuteOfDay(cfg.tokenOpensMinute),
    closesAt: formatMinuteOfDay(cfg.tokenClosesMinute),
    queueStartAt: formatMinuteOfDay(cfg.queueStartMinute),
    opensAtUtc: opensAt.toISOString(),
    closesAtUtc: closesAt.toISOString(),
    queueStartUtc: queueStart.toISOString(),
  };

  const deny = (
    status: TokenWindowStatus,
    reason: string,
    errorCode: NonNullable<TokenWindow["errorCode"]>,
  ): TokenWindow => ({ ...base, status, bookable: false, reason, errorCode });

  if (!allowsTokenBooking(cfg.bookingMode)) {
    return deny(
      "UNAVAILABLE",
      "This doctor only takes scheduled appointments.",
      "TOKEN_BOOKING_UNAVAILABLE",
    );
  }

  const nowMs = now.getTime();
  if (nowMs < opensAt.getTime()) {
    return deny(
      "NOT_YET_OPEN",
      `Token booking opens today at ${base.opensAt}.`,
      "TOKEN_BOOKING_NOT_OPEN",
    );
  }
  if (nowMs >= closesAt.getTime()) {
    return deny(
      "CLOSED",
      `Token booking closed today at ${base.closesAt}.`,
      "TOKEN_BOOKING_CLOSED",
    );
  }
  if (tokensIssued >= cfg.maxDailyTokens) {
    return deny(
      "CLOSED",
      `All ${cfg.maxDailyTokens} tokens for today have been issued.`,
      "TOKEN_LIMIT_REACHED",
    );
  }

  return { ...base, status: "OPEN", bookable: true, reason: null, errorCode: null };
}

/** The clinic-local calendar day a UTC instant belongs to, as a Prisma `@db.Date`. */
export function clinicLocalDate(instant: Date, timezone: string): Date {
  const p = localPartsInZone(instant, timezone);
  return new Date(Date.UTC(p.year, p.month - 1, p.day));
}

/** Today's local minute-of-day — used to order "not yet open" ahead of "closed". */
export function localMinuteNow(now: Date, timezone: string): number {
  return localMinuteOfDay(localPartsInZone(now, timezone));
}