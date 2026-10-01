/**
 * Unit tests for the pure token-window maths (TOKEN_BOOKING_ASSESSMENT.md §33).
 * No DB, no auth — these are the rules that must hold no matter who calls.
 */
import { describe, it, expect } from "vitest";
import {
  assertValidTokenWindow,
  computeTokenWindow,
  formatMinuteOfDay,
  clinicLocalDate,
  allowsTokenBooking,
  type TokenWindowConfig,
} from "../../src/modules/tokens/window.js";

const BASE: TokenWindowConfig = {
  bookingMode: "SAME_DAY_TOKEN",
  tokenOpensMinute: 420, // 07:00
  tokenClosesMinute: 660, // 11:00
  queueStartMinute: 540, // 09:00
  maxDailyTokens: 50,
  consultationDurationMin: 15,
};

// Asia/Kolkata is UTC+5:30 with no DST, so local wall time == UTC + 5:30 all
// year — ideal for asserting "the server's clock, in the clinic's zone".
const TZ = "Asia/Kolkata";

/**
 * A UTC instant that reads as `hh:mm` local wall time in TZ on 2026-10-01.
 * Asia/Kolkata is a fixed +05:30 with no DST, so this is exact arithmetic.
 *
 * Computed in whole MINUTES, not fractional hours: `Date.UTC` applies
 * `ToIntegerOrInfinity` to the hour argument, so `Date.UTC(y, m, d, 1.5)`
 * silently becomes 01:00 — which would have quietly shifted every boundary
 * assertion by 30 minutes.
 */
function at(hh: number, mm: number): Date {
  const IST_OFFSET_MIN = 5 * 60 + 30;
  return new Date(Date.UTC(2026, 9, 1, 0, hh * 60 + mm - IST_OFFSET_MIN));
}

describe("formatMinuteOfDay", () => {
  it("formats minutes as 24h wall clock", () => {
    expect(formatMinuteOfDay(0)).toBe("00:00");
    expect(formatMinuteOfDay(420)).toBe("07:00");
    expect(formatMinuteOfDay(660)).toBe("11:00");
    expect(formatMinuteOfDay(1439)).toBe("23:59");
  });
});

describe("allowsTokenBooking", () => {
  it("is true only for the two token-capable modes", () => {
    expect(allowsTokenBooking("SAME_DAY_TOKEN")).toBe(true);
    expect(allowsTokenBooking("BOTH")).toBe(true);
    expect(allowsTokenBooking("SCHEDULED")).toBe(false);
  });
});

describe("assertValidTokenWindow", () => {
  const valid = { tokenOpensMinute: 420, tokenClosesMinute: 660, queueStartMinute: 540, maxDailyTokens: 50 };

  it("accepts a coherent window", () => {
    expect(() => assertValidTokenWindow(valid)).not.toThrow();
  });

  it("rejects a window that closes before it opens", () => {
    expect(() => assertValidTokenWindow({ ...valid, tokenClosesMinute: 400 })).toThrow(/close after it opens/i);
  });

  it("rejects queue start outside the booking window", () => {
    expect(() => assertValidTokenWindow({ ...valid, queueStartMinute: 400 })).toThrow(/inside the token booking window/i);
    expect(() => assertValidTokenWindow({ ...valid, queueStartMinute: 700 })).toThrow(/inside the token booking window/i);
  });

  it("rejects out-of-range minutes and caps", () => {
    expect(() => assertValidTokenWindow({ ...valid, tokenOpensMinute: 1440 })).toThrow(/whole minute/i);
    expect(() => assertValidTokenWindow({ ...valid, tokenOpensMinute: 10.5 })).toThrow(/whole minute/i);
    expect(() => assertValidTokenWindow({ ...valid, maxDailyTokens: 0 })).toThrow(/between 1 and 1000/i);
  });
});

describe("computeTokenWindow", () => {
  it("is NOT_YET_OPEN before the opening minute (spec: no hardcoded 7am — the config decides)", () => {
    const w = computeTokenWindow(BASE, TZ, at(6, 59));
    expect(w.status).toBe("NOT_YET_OPEN");
    expect(w.bookable).toBe(false);
    expect(w.errorCode).toBe("TOKEN_BOOKING_NOT_OPEN");
    expect(w.opensAt).toBe("07:00");
  });

  it("is OPEN exactly at the opening minute (boundary is inclusive)", () => {
    const w = computeTokenWindow(BASE, TZ, at(7, 0));
    expect(w.status).toBe("OPEN");
    expect(w.bookable).toBe(true);
  });

  it("is OPEN just before the closing minute", () => {
    expect(computeTokenWindow(BASE, TZ, at(10, 59)).bookable).toBe(true);
  });

  it("is CLOSED exactly at the closing minute (boundary is exclusive)", () => {
    const w = computeTokenWindow(BASE, TZ, at(11, 0));
    expect(w.status).toBe("CLOSED");
    expect(w.errorCode).toBe("TOKEN_BOOKING_CLOSED");
  });

  it("is UNAVAILABLE when the doctor only takes scheduled appointments", () => {
    const w = computeTokenWindow({ ...BASE, bookingMode: "SCHEDULED" }, TZ, at(8, 0));
    expect(w.status).toBe("UNAVAILABLE");
    expect(w.errorCode).toBe("TOKEN_BOOKING_UNAVAILABLE");
    // Booking mode beats window timing — must not say "opens at 07:00".
    expect(w.reason).not.toMatch(/opens/i);
  });

  it("is BOTH-openable: a BOTH doctor can still take tokens inside the window", () => {
    expect(computeTokenWindow({ ...BASE, bookingMode: "BOTH" }, TZ, at(8, 0)).bookable).toBe(true);
  });

  it("reports TOKEN_LIMIT_REACHED once the daily cap is hit", () => {
    const w = computeTokenWindow(BASE, TZ, at(8, 0), 50);
    expect(w.status).toBe("CLOSED");
    expect(w.errorCode).toBe("TOKEN_LIMIT_REACHED");
    expect(w.reason).toMatch(/50 tokens/);
  });

  it("allows the cap-th token (cap is 'max', not 'off by one')", () => {
    expect(computeTokenWindow(BASE, TZ, at(8, 0), 49).bookable).toBe(true);
  });

  it("derives 'today' from the clinic zone, not UTC — a 21:30 UTC instant is already tomorrow in Kolkata", () => {
    // 2026-10-01 19:00 UTC == 2026-10-02 00:30 in Asia/Kolkata.
    const lateUtc = new Date(Date.UTC(2026, 9, 1, 19, 0));
    const w = computeTokenWindow(BASE, TZ, lateUtc);
    // 00:30 local on Oct 2 -> before the 07:00 open, and the date is Oct 2.
    expect(w.date).toBe("2026-10-02");
    expect(w.status).toBe("NOT_YET_OPEN");
  });

  it("never reports a future date — the date is always today in the clinic zone", () => {
    const w = computeTokenWindow(BASE, TZ, new Date());
    const todayKolkata = new Intl.DateTimeFormat("en-CA", { timeZone: TZ }).format(new Date());
    expect(w.date).toBe(todayKolkata);
  });

  it("exposes UTC instants that match the configured local times", () => {
    const w = computeTokenWindow(BASE, TZ, at(8, 0));
    // 07:00 IST == 01:30 UTC.
    expect(new Date(w.opensAtUtc).toISOString()).toBe("2026-10-01T01:30:00.000Z");
    // 09:00 IST == 03:30 UTC.
    expect(new Date(w.queueStartUtc).toISOString()).toBe("2026-10-01T03:30:00.000Z");
  });

  it("handles a DST transition zone without drifting an hour", () => {
    // America/New_York falls back at 02:00 on 2026-11-01. 12:00Z is already
    // 07:00 EST (-5) that morning, so the 09:00 queue start is 14:00Z. A naive
    // implementation that froze the zone's standard offset (or cached a DST
    // offset from a summer date) would produce 13:00Z here.
    const dstDay = new Date(Date.UTC(2026, 10, 1, 12, 0));
    const w = computeTokenWindow(BASE, "America/New_York", dstDay);
    expect(new Date(w.queueStartUtc).toISOString()).toBe("2026-11-01T14:00:00.000Z");
  });
});

describe("clinicLocalDate", () => {
  it("maps an instant to the clinic-local calendar day", () => {
    // 18:30 UTC == 00:00 next day in Kolkata.
    expect(clinicLocalDate(new Date(Date.UTC(2026, 9, 1, 18, 30)), TZ).toISOString().slice(0, 10)).toBe("2026-10-02");
  });

  it("maps a mid-afternoon UTC instant to the same local day", () => {
    expect(clinicLocalDate(new Date(Date.UTC(2026, 9, 1, 6, 0)), TZ).toISOString().slice(0, 10)).toBe("2026-10-01");
  });
});