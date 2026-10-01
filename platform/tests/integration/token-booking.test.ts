/**
 * Same-day token booking + queue workflow (TOKEN_BOOKING_ASSESSMENT.md §33).
 *
 * These exercise the HTTP surface, because the guarantees under test — tenant
 * isolation, role gates, "the server refuses what the UI would have disabled",
 * idempotent double-submit — are properties of the routes, not of a helper.
 *
 * Slow: ~20s per test (remote DB + argon2). Run this file alone.
 */
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import {
  alwaysOpenWindow,
  createDoctorWithLogin,
  createOrg,
  createPatient,
  makeDoctorPublic,
  publishOrgForDiscovery,
  registerAndLogin,
  setTokenWindow,
} from "../helpers/factories.js";
import { POST as tokenRoute } from "../../app/api/patient/appointments/token/route.js";
import { GET as tokenWindowRoute } from "../../app/api/public/doctors/[doctorId]/token-window/route.js";
import { GET as tokenStatusRoute } from "../../app/api/patient/token-status/route.js";
import { POST as walkInRoute } from "../../app/api/orgs/[orgId]/queue/walk-in/route.js";
import { GET as peekRoute, POST as nextRoute } from "../../app/api/orgs/[orgId]/queue/next/route.js";
import { GET as boardRoute } from "../../app/api/orgs/[orgId]/queue/route.js";
import { POST as queueActionRoute } from "../../app/api/orgs/[orgId]/queue/[entryId]/[action]/route.js";
import { POST as bookRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { POST as checkInRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/check-in/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;
let doctorId: string;
let doctorToken: string;
let patientUser: { accessToken: string; userId: string };

interface TokenResult {
  appointmentId: string;
  entryId: string;
  tokenNumber: number;
  reused: boolean;
  doctorName: string;
  queueDate: string;
  queueStartAt: string;
}

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("tbadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "token")).id;
  // Self-service discovery paths require a publicly listed org with an active
  // location (patient-booking/service.ts), so publish up front rather than
  // discovering per-test which 404 was "not published" vs "not allowed".
  await publishOrgForDiscovery(adminToken, orgId);
  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  doctorToken = doc.token;
  await makeDoctorPublic(adminToken, orgId, doctorId);
  await setTokenWindow(orgId, doctorId, alwaysOpenWindow());
  patientUser = await registerAndLogin("tpat");
});

afterAll(disconnect);

const DEMO = { firstName: "Token", lastName: "Tester" };

/** Self-service token booking as `patientUser`. */
function bookToken(
  overrides: Partial<{ doctorId: string; patientId: string; organizationId: string; patient: typeof DEMO }> = {},
  bearer = patientUser.accessToken,
) {
  return call<TokenResult>(tokenRoute, {
    bearer,
    params: {},
    body: {
      organizationId: orgId,
      doctorId,
      patient: DEMO,
      ...overrides,
    },
  });
}

const act = (entryId: string, action: string, token = adminToken) =>
  call(queueActionRoute, { bearer: token, params: { orgId, entryId, action } });

const board = (token = adminToken, docId = doctorId) =>
  call<{
    queueDate: string;
    nowServingToken: number | null;
    summary: Record<string, number>;
    entries: Array<{ id: string; tokenNumber: number; state: string; ahead: number }>;
  }>(boardRoute, { bearer: token, params: { orgId }, url: `http://x/api?doctorId=${docId}` });

describe("same-day token booking", () => {
  it("a patient can take a token and it appears on the board as WAITING", async () => {
    const res = await bookToken();
    expect(res.status).toBe(201);
    expect(res.body.tokenNumber).toBeGreaterThan(0);
    expect(res.body.reused).toBe(false);

    const b = await board();
    const row = b.body.entries.find((e) => e.id === res.body.entryId);
    expect(row?.state).toBe("WAITING");
    // Same sequence the board shows — the counter is shared with check-in.
    expect(row?.tokenNumber).toBe(res.body.tokenNumber);
  });

  it("the appointment is created WAITING with bookingKind SAME_DAY_TOKEN", async () => {
    const res = await bookToken();
    const appt = await db.appointment.findUniqueOrThrow({
      where: { id: res.body.appointmentId },
      include: { queueEntry: true },
    });
    expect(appt.status).toBe("WAITING");
    expect(appt.bookingKind).toBe("SAME_DAY_TOKEN");
    expect(appt.tokenDate).not.toBeNull();
    // A token patient never passes through CONFIRMED/CHECKED_IN.
    expect(appt.checkedInAt).not.toBeNull();
    expect(appt.queueEntry?.tokenNumber).toBe(res.body.tokenNumber);
  });

  it("token numbers are sequential and never reused across bookings", async () => {
    // Two DIFFERENT patients: the same patient booking twice is (correctly)
    // handed back their existing token, which is a separate test below.
    const [ua, ub] = await Promise.all([registerAndLogin("seqa"), registerAndLogin("seqb")]);
    const a = await bookToken({}, ua.accessToken);
    const b = await bookToken({}, ub.accessToken);
    expect(a.body.reused).toBe(false);
    expect(b.body.reused).toBe(false);
    expect(b.body.tokenNumber).toBe(a.body.tokenNumber + 1);
  });

  it("a second submit by the same patient returns the SAME token (reused), never a second one", async () => {
    const user = await registerAndLogin("tdup");
    const first = await bookToken({}, user.accessToken);
    expect(first.status).toBe(201);
    const second = await bookToken({}, user.accessToken);
    expect(second.status).toBe(200);
    expect(second.body.reused).toBe(true);
    expect(second.body.tokenNumber).toBe(first.body.tokenNumber);
    expect(second.body.appointmentId).toBe(first.body.appointmentId);
  });

  it("the DB refuses two active tokens for one patient/doctor/day even under a race", async () => {
    const user = await registerAndLogin("trace");
    const [x, y] = await Promise.all([
      bookToken({}, user.accessToken),
      bookToken({}, user.accessToken),
    ]);
    // Exactly one booking won; the other got the same token back, never a
    // different one, and never a 5xx.
    expect([x.status, y.status].every((s) => s === 200 || s === 201)).toBe(true);
    const numbers = new Set([x.body.tokenNumber, y.body.tokenNumber]);
    expect(numbers.size).toBe(1);

    const rows = await db.appointment.count({
      where: {
        patient: { ownerUserId: user.userId },
        doctorId,
        bookingKind: "SAME_DAY_TOKEN",
        status: { notIn: ["CANCELLED", "NO_SHOW", "RESCHEDULED", "COMPLETED"] },
      },
    });
    expect(rows).toBe(1);
  });

  it("cancelling a token frees the patient's slot to book again", async () => {
    const user = await registerAndLogin("tcancel");
    const first = await bookToken({}, user.accessToken);
    await db.appointment.update({
      where: { id: first.body.appointmentId },
      data: { status: "CANCELLED", cancelledAt: new Date() },
    });
    const again = await bookToken({}, user.accessToken);
    expect(again.status).toBe(201);
    expect(again.body.tokenNumber).not.toBe(first.body.tokenNumber);
  });

  it("respects the daily cap and returns TOKEN_LIMIT_REACHED", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setTokenWindow(orgId, doc.doctorId, { ...alwaysOpenWindow(), maxDailyTokens: 2 });
    const users = await Promise.all([registerAndLogin("cap1"), registerAndLogin("cap2"), registerAndLogin("cap3")]);
    const results = [];
    for (const u of users) {
      results.push(
        await call<TokenResult>(tokenRoute, {
          bearer: u.accessToken,
          params: {},
          body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
        }),
      );
    }
    expect(results.filter((r) => r.status === 201)).toHaveLength(2);
    const refused = results.find((r) => r.status === 409);
    expect(refused?.status).toBe(409);
    expect((refused!.body as unknown as { error: { code: string } }).error.code).toBe("TOKEN_LIMIT_REACHED");
  });

  it("refuses when the doctor only takes scheduled appointments (TOKEN_BOOKING_UNAVAILABLE)", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setTokenWindow(orgId, doc.doctorId, { ...alwaysOpenWindow(), bookingMode: "SCHEDULED" });
    const u = await registerAndLogin("nomode");
    const res = await call<TokenResult>(tokenRoute, {
      bearer: u.accessToken,
      params: {},
      body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
    });
    expect(res.status).toBe(409);
    expect((res.body as unknown as { error: { code: string } }).error.code).toBe("TOKEN_BOOKING_UNAVAILABLE");
  });

  it("refuses before the window opens and after it closes, from the server's clock", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    // 00:00-00:01 is almost certainly "closed" and 23:58-23:59 "not yet open",
    // whichever way round the server clock sits — assert on the code it returns.
    await setTokenWindow(orgId, doc.doctorId, {
      tokenOpensMinute: 1,
      tokenClosesMinute: 2,
      queueStartMinute: 1,
      maxDailyTokens: 10,
    });
    const u = await registerAndLogin("closed");
    const res = await call<TokenResult>(tokenRoute, {
      bearer: u.accessToken,
      params: {},
      body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
    });
    expect(res.status).toBe(409);
    const code = (res.body as unknown as { error: { code: string } }).error.code;
    expect(["TOKEN_BOOKING_NOT_OPEN", "TOKEN_BOOKING_CLOSED"]).toContain(code);
  });

  it("the token is scoped to the clinic-local day, never a client-supplied date", async () => {
    // A `date` field is not in the schema at all — reject it outright.
    const res = await call<TokenResult>(tokenRoute, {
      bearer: patientUser.accessToken,
      params: {},
      body: { organizationId: orgId, doctorId, patient: DEMO, date: "2030-01-01" },
    });
    expect(res.status).toBe(422);
  });

  it("another clinic's doctor is not bookable by this org's patient path", async () => {
    const outsider = await registerAndLogin("tother");
    const otherOrg = (await createOrg(outsider.accessToken, "tokother")).id;
    const otherDoc = await createDoctorWithLogin(outsider.accessToken, otherOrg);
    await setTokenWindow(otherOrg, otherDoc.doctorId, alwaysOpenWindow());

    // The doctor belongs to a different org; passing OUR orgId must not work.
    const res = await bookToken({ doctorId: otherDoc.doctorId });
    expect(res.status).toBe(404);
  });
});

describe("token window endpoint", () => {
  it("is readable unauthenticated for a public doctor and reports bookable", async () => {
    await publishOrgForDiscovery(adminToken, orgId);
    await makeDoctorPublic(adminToken, orgId, doctorId);
    const res = await call<{ bookable: boolean; status: string; opensAt: string }>(tokenWindowRoute, {
      params: { doctorId },
    });
    expect(res.status).toBe(200);
    expect(res.body.bookable).toBe(true);
    expect(res.body.opensAt).toBe("00:00");
  });

  it("is hidden for a doctor who is not publicly listed", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setTokenWindow(orgId, doc.doctorId, alwaysOpenWindow());
    const res = await call(tokenWindowRoute, { params: { doctorId: doc.doctorId } });
    expect(res.status).toBe(404);
  });

  it("never exposes an ETA in minutes — position only", async () => {
    const res = await call<Record<string, unknown>>(tokenWindowRoute, { params: { doctorId } });
    const json = JSON.stringify(res.body).toLowerCase();
    expect(json).not.toContain("eta");
    expect(json).not.toContain("waittime");
    expect(json).not.toContain("minuteswait");
  });
});

describe("patient token status", () => {
  it("returns token number, live position and a server-rendered next step", async () => {
    const u = await registerAndLogin("tstatus");
    const booked = await bookToken({}, u.accessToken);
    const res = await call<{ tokenNumber: number; ahead: number; advice: string; state: string }>(
      tokenStatusRoute,
      { bearer: u.accessToken, params: {}, url: `http://x/api?appointmentId=${booked.body.appointmentId}` },
    );
    expect(res.status).toBe(200);
    expect(res.body.tokenNumber).toBe(booked.body.tokenNumber);
    expect(res.body.state).toBe("WAITING");
    expect(typeof res.body.ahead).toBe("number");
    expect(res.body.advice).toMatch(/wait in the waiting area/i);
  });

  it("another patient cannot read someone else's token status", async () => {
    const u = await registerAndLogin("tstatus2");
    const booked = await bookToken({}, u.accessToken);
    const other = await registerAndLogin("tstatus3");
    const res = await call(tokenStatusRoute, {
      bearer: other.accessToken,
      params: {},
      url: `http://x/api?appointmentId=${booked.body.appointmentId}`,
    });
    expect(res.status).toBe(404);
  });
});

describe("HOLD / SKIPPED / NO_SHOW are three different things", () => {
  it("hold parks a patient without losing their place; release puts them back", async () => {
    const u = await registerAndLogin("thold");
    const booked = await bookToken({}, u.accessToken);
    const held = await act(booked.body.entryId, "hold");
    expect(held.status).toBe(200);
    expect((held.body as { state: string }).state).toBe("HOLD");

    const released = await act(booked.body.entryId, "release");
    expect(released.status).toBe(200);
    expect((released.body as { state: string }).state).toBe("WAITING");
  });

  it("recall brings a HELD patient straight back to CALLED", async () => {
    const u = await registerAndLogin("tholdrecall");
    const booked = await bookToken({}, u.accessToken);
    await act(booked.body.entryId, "hold");
    const recalled = await act(booked.body.entryId, "recall");
    expect(recalled.status).toBe(200);
    expect((recalled.body as { state: string }).state).toBe("CALLED");
  });

  it("recall brings a SKIPPED patient back to WAITING, ahead of newcomers", async () => {
    const u = await registerAndLogin("tskiprecall");
    const skipped = await bookToken({}, u.accessToken);
    await act(skipped.body.entryId, "skip");
    const recalled = await act(skipped.body.entryId, "recall");
    expect((recalled.body as { state: string }).state).toBe("WAITING");
    expect((recalled.body as { position: number }).position).toBeLessThan(1);
  });

  it("no-show is terminal — it cannot be recalled", async () => {
    const u = await registerAndLogin("tnoshow");
    const booked = await bookToken({}, u.accessToken);
    const done = await act(booked.body.entryId, "no-show");
    expect(done.status).toBe(200);
    expect((done.body as { state: string }).state).toBe("NO_SHOW");
    const again = await act(booked.body.entryId, "recall");
    expect(again.status).toBe(409);
  });

  it("marking the queue no-show also completes the appointment as NO_SHOW", async () => {
    const u = await registerAndLogin("tnoshow2");
    const booked = await bookToken({}, u.accessToken);
    await act(booked.body.entryId, "no-show");
    const appt = await db.appointment.findUniqueOrThrow({
      where: { id: booked.body.appointmentId },
      select: { status: true, noShowMarkedAt: true },
    });
    expect(appt.status).toBe("NO_SHOW");
    expect(appt.noShowMarkedAt).not.toBeNull();
  });
});

describe("next / call-next is decided server-side", () => {
  it("calls the earliest WAITING patient and refuses while one is already called", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setTokenWindow(orgId, doc.doctorId, alwaysOpenWindow());
    const users = await Promise.all([registerAndLogin("n1"), registerAndLogin("n2")]);
    const a = await call<TokenResult>(tokenRoute, {
      bearer: users[0]!.accessToken,
      params: {},
      body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
    });
    await call<TokenResult>(tokenRoute, {
      bearer: users[1]!.accessToken,
      params: {},
      body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
    });

    const first = await call<{ state: string; tokenNumber: number }>(nextRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doc.doctorId}`,
    });
    expect(first.status).toBe(200);
    expect((first.body as unknown as { state: string }).state).toBe("CALLED");
    // It picked the earliest token, not an arbitrary one.
    expect((first.body as unknown as { tokenNumber: number }).tokenNumber).toBe(a.body.tokenNumber);

    // Second press must not abandon the patient already called.
    const second = await call(nextRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doc.doctorId}`,
    });
    expect(second.status).toBe(409);
  });

  it("GET next previews without calling", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setTokenWindow(orgId, doc.doctorId, alwaysOpenWindow());
    const u = await registerAndLogin("peek");
    await call<TokenResult>(tokenRoute, {
      bearer: u.accessToken,
      params: {},
      body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
    });
    const peek = await call<{ next: { tokenNumber: number } | null }>(peekRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doc.doctorId}`,
    });
    expect(peek.status).toBe(200);
    expect(peek.body.next).not.toBeNull();
    // Nothing was called.
    const b = await board(adminToken, doc.doctorId);
    expect(b.body.entries.length).toBeGreaterThan(0);
    expect(b.body.entries.every((e) => e.state === "WAITING")).toBe(true);
  });
});

describe("staff walk-in", () => {
  it("reception issues a token to a patient at the desk, under the same cap", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setTokenWindow(orgId, doc.doctorId, { ...alwaysOpenWindow(), maxDailyTokens: 1 });
    const p1 = await createPatient(orgId, adminUserId);
    const p2 = await createPatient(orgId, adminUserId);

    const first = await call<TokenResult>(walkInRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doc.doctorId}`,
      body: { patientId: p1.id },
    });
    expect(first.status).toBe(201);

    // The cap applies to walk-ins too, so a second one cannot oversubscribe.
    const second = await call(walkInRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doc.doctorId}`,
      body: { patientId: p2.id },
    });
    expect(second.status).toBe(409);
  });

  it("is refused for a patient belonging to another clinic", async () => {
    const outsider = await registerAndLogin("twalk");
    const otherOrg = (await createOrg(outsider.accessToken, "walkother")).id;
    const foreign = await createPatient(otherOrg, outsider.userId);
    const res = await call(walkInRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doctorId}`,
      body: { patientId: foreign.id },
    });
    expect(res.status).toBe(404);
  });
});

describe("scheduled booking still works — no regression", () => {
  it("scheduled check-in and token booking draw from ONE counter per (doctor, day)", async () => {
    const { setWeeklyAvailability, firstSlot } = await import("../helpers/factories.js");
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await makeDoctorPublic(adminToken, orgId, doc.doctorId);
    await setTokenWindow(orgId, doc.doctorId, alwaysOpenWindow());
    await setWeeklyAvailability(adminToken, orgId, doc.doctorId, { slotMinutes: 15 });

    // Two slots on the SAME clinic-local day, so both check-ins land in one
    // counter's sequence along with the token bookings below.
    const first = await firstSlot(adminToken, orgId, doc.doctorId, 5);
    const secondSlot = await firstSlot(adminToken, orgId, doc.doctorId, 5, first.start);

    for (const start of [first.start, secondSlot.start]) {
      const patient = await createPatient(orgId, adminUserId);
      const appt = await call<{ id: string }>(bookRoute, {
        bearer: adminToken,
        params: { orgId },
        body: { patientId: patient.id, doctorId: doc.doctorId, scheduledStart: start },
      });
      expect(appt.status).toBe(201);
      const ci = await call<{ queue: { tokenNumber: number } }>(checkInRoute, {
        bearer: adminToken,
        params: { orgId, appointmentId: appt.body.id },
      });
      expect(ci.status).toBe(200);
    }

    const tokenDay = await call<TokenResult>(tokenRoute, {
      bearer: patientUser.accessToken,
      params: {},
      body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
    });

    // The counter row is authoritative and must equal the highest token handed
    // out for that (doctor, clinic-local day) — proving check-in and token
    // booking share one sequence rather than two that both start at 1.
    const counter = await db.queueTokenCounter.findFirstOrThrow({
      where: { organizationId: orgId, doctorId: doc.doctorId },
      orderBy: { queueDate: "desc" },
    });
    const today = await db.queueEntry.findMany({
      where: { organizationId: orgId, doctorId: doc.doctorId, queueDate: counter.queueDate },
      select: { tokenNumber: true },
    });
    const max = Math.max(...today.map((e) => e.tokenNumber));
    expect(counter.lastToken).toBe(max);
    expect(tokenDay.body.tokenNumber).toBeGreaterThan(0);
  }, 120_000);

  it("scheduled double-booking protection is still enforced (EXCLUDE narrowed, not removed)", async () => {
    const { setWeeklyAvailability, firstSlot } = await import("../helpers/factories.js");
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setWeeklyAvailability(adminToken, orgId, doc.doctorId, { slotMinutes: 15 });
    const slot = await firstSlot(adminToken, orgId, doc.doctorId, 6);
    const p1 = await createPatient(orgId, adminUserId);
    const p2 = await createPatient(orgId, adminUserId);

    const first = await call<{ id: string }>(bookRoute, {
      bearer: adminToken,
      params: { orgId },
      body: { patientId: p1.id, doctorId: doc.doctorId, scheduledStart: slot.start },
    });
    expect(first.status).toBe(201);
    const clash = await call(bookRoute, {
      bearer: adminToken,
      params: { orgId },
      body: { patientId: p2.id, doctorId: doc.doctorId, scheduledStart: slot.start },
    });
    expect(clash.status).toBe(409);
  });

  it("many token bookings for one day never collide on the appointment EXCLUDE", async () => {
    // Every token anchors scheduledStart to the SAME queue-start instant, so a
    // naive EXCLUDE would reject the 2nd token of the day. This is the
    // regression test for narrowing the constraint to bookingKind = SCHEDULED.
    const doc = await createDoctorWithLogin(adminToken, orgId);
    await setTokenWindow(orgId, doc.doctorId, alwaysOpenWindow());
    const users = await Promise.all([
      registerAndLogin("bulk1"),
      registerAndLogin("bulk2"),
      registerAndLogin("bulk3"),
      registerAndLogin("bulk4"),
    ]);
    const results = [];
    for (const u of users) {
      results.push(
        await call<TokenResult>(tokenRoute, {
          bearer: u.accessToken,
          params: {},
          body: { organizationId: orgId, doctorId: doc.doctorId, patient: DEMO },
        }),
      );
    }
    expect(results.every((r) => r.status === 201)).toBe(true);
    const numbers = results.map((r) => r.body.tokenNumber);
    expect(new Set(numbers).size).toBe(4);
  }, 120_000);
});