/**
 * Same-day token production-hardening QA (2026-10-01).
 *
 * Drives a whole clinic morning through the real route handlers and checks the
 * DATABASE after every step that matters — not just the HTTP status. Covers the
 * gaps the booking/workflow suites leave: side effects of refused bookings,
 * counter scoping across doctors/days, 20-way concurrency, the cap under
 * concurrency, timestamps/notifications/audit, SKIP-recall ordering, NO_SHOW
 * finality, closed-window operation, cancellation policy, privacy, the
 * consultation-page path, and the final 4-patient acceptance scenario.
 *
 * DESTRUCTIVE: truncates every app table in DATABASE_URL (like every
 * integration suite). Reseed the demo DB afterwards: `pnpm db:seed`.
 */
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
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
  relogin,
  setTokenWindow,
} from "../helpers/factories.js";
import { allocateTokenNumber } from "../../src/modules/queue/service.js";
import { localMinuteNow } from "../../src/modules/tokens/window.js";
import { POST as tokenRoute } from "../../app/api/patient/appointments/token/route.js";
import { GET as tokenStatusRoute } from "../../app/api/patient/token-status/route.js";
import { POST as nextRoute } from "../../app/api/orgs/[orgId]/queue/next/route.js";
import { GET as boardRoute } from "../../app/api/orgs/[orgId]/queue/route.js";
import { POST as queueActionRoute } from "../../app/api/orgs/[orgId]/queue/[entryId]/[action]/route.js";
import { POST as cancelRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/cancel/route.js";
import { POST as startApptRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/start/route.js";
import { POST as completeApptRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/complete/route.js";
import { PUT as saveConsultationRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/route.js";
import { POST as signRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/consultation/sign/route.js";
import { POST as addItemRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/prescription-items/route.js";
import { PATCH as updateDoctorRoute } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/route.js";

let adminToken: string;
let adminUserId: string;
let adminEmail: string;
let orgId: string;
let tz: string;

interface TokenResult {
  appointmentId: string;
  entryId: string;
  tokenNumber: number;
  reused: boolean;
}
type BoardEntry = { id: string; tokenNumber: number; state: string; position: number; actions: string[] };
type Board = { summary: Record<string, number>; nowServingToken: number | null; entries: BoardEntry[] };

const DEMO = { firstName: "QA", lastName: "Patient" };
const LONG = 300_000;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("qaadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  adminEmail = admin.email;
  orgId = (await createOrg(adminToken, "abcclinic")).id;
  await publishOrgForDiscovery(adminToken, orgId);
  tz = (await db.organization.findUniqueOrThrow({ where: { id: orgId }, select: { timezone: true } })).timezone;
});

// This suite runs ~20 minutes against a remote DB — longer than the access-token
// TTL — so the clinic admin logs in again before each test.
beforeEach(async () => {
  adminToken = await relogin(adminEmail);
});

afterAll(disconnect);

async function tokenDoctor(cfg: Partial<ReturnType<typeof alwaysOpenWindow>> & { bookingMode?: "SAME_DAY_TOKEN" | "BOTH" } = {}) {
  const doc = await createDoctorWithLogin(adminToken, orgId);
  await makeDoctorPublic(adminToken, orgId, doc.doctorId);
  await setTokenWindow(orgId, doc.doctorId, { ...alwaysOpenWindow(), bookingMode: "BOTH", ...cfg });
  return doc;
}

const book = (bearer: string, doctorId: string, extra: Record<string, unknown> = {}) =>
  call<TokenResult & { error?: { code: string; message: string } }>(tokenRoute, {
    bearer,
    params: {},
    body: { organizationId: orgId, doctorId, patient: DEMO, ...extra },
  });

const act = (entryId: string, action: string, bearer = adminToken, org = orgId) =>
  call<{ state: string; tokenNumber: number; position: number; error?: { code: string } }>(queueActionRoute, {
    bearer,
    params: { orgId: org, entryId, action },
  });

const next = (doctorId: string, bearer = adminToken) =>
  call<{ state: string; tokenNumber: number; id: string }>(nextRoute, {
    bearer,
    params: { orgId },
    url: `http://x/api?doctorId=${doctorId}`,
  });

const board = (doctorId: string, bearer = adminToken, org = orgId) =>
  call<Board>(boardRoute, { bearer, params: { orgId: org }, url: `http://x/api?doctorId=${doctorId}` });

const status = (bearer: string, appointmentId: string) =>
  call<{ state: string; tokenNumber: number; ahead: number; nowServingToken: number | null; appointmentStatus: string; advice: string }>(
    tokenStatusRoute,
    { bearer, url: `http://x/api?appointmentId=${appointmentId}` },
  );

const apptRoute = (route: typeof cancelRoute, appointmentId: string, bearer: string, body?: unknown, org = orgId) =>
  call<{ status?: string; error?: { code: string } }>(route, { bearer, params: { orgId: org, appointmentId }, body });

async function users(n: number, prefix: string) {
  const out = [];
  for (let i = 0; i < n; i++) out.push(await registerAndLogin(`${prefix}${i}`));
  return out;
}

const counter = async (doctorId: string) =>
  (await db.queueTokenCounter.findFirst({ where: { organizationId: orgId, doctorId } }))?.lastToken ?? 0;

// ---------------------------------------------------------------------------

describe("§4 before opening — a refused booking leaves no trace", () => {
  it("rejects server-side and creates no appointment, entry, counter or notification", async () => {
    const now = localMinuteNow(new Date(), tz);
    // Needs ≥ 2 minutes of day left after "now" to express a future window.
    if (now > 1436) return;
    const doc = await tokenDoctor({ tokenOpensMinute: now + 2, tokenClosesMinute: 1439, queueStartMinute: now + 2 });
    const u = await registerAndLogin("early");
    const before = await db.notification.count();

    const res = await book(u.accessToken, doc.doctorId);
    expect(res.status).toBe(409);
    expect(res.body.error?.code).toBe("TOKEN_BOOKING_NOT_OPEN");
    expect(await db.appointment.count({ where: { doctorId: doc.doctorId } })).toBe(0);
    expect(await db.queueEntry.count({ where: { doctorId: doc.doctorId } })).toBe(0);
    expect(await counter(doc.doctorId)).toBe(0);
    // The only notifications created are none for this doctor's booking.
    const created = await db.notification.findMany({ skip: before, select: { event: true } });
    expect(created.filter((n) => n.event === "QUEUE_UPDATE")).toHaveLength(0);
  }, LONG);
});

describe("§5 opening — tokens 1/2/3 with every column correct", () => {
  it("writes SAME_DAY_TOKEN appointments + WAITING entries with the right ids", async () => {
    const doc = await tokenDoctor();
    const loc = await db.clinicLocation.findFirstOrThrow({ where: { organizationId: orgId } });
    const [a, b, c] = await users(3, "open");
    const res = [
      await book(a!.accessToken, doc.doctorId, { locationId: loc.id }),
      await book(b!.accessToken, doc.doctorId, { locationId: loc.id }),
      await book(c!.accessToken, doc.doctorId, { locationId: loc.id }),
    ];
    expect(res.map((r) => r.body.tokenNumber)).toEqual([1, 2, 3]);

    for (const [i, r] of res.entries()) {
      const appt = await db.appointment.findUniqueOrThrow({
        where: { id: r.body.appointmentId },
        include: { queueEntry: true, patient: { select: { ownerUserId: true } } },
      });
      expect(appt).toMatchObject({
        organizationId: orgId,
        doctorId: doc.doctorId,
        locationId: loc.id,
        bookingKind: "SAME_DAY_TOKEN",
        status: "WAITING",
      });
      expect(appt.patient.ownerUserId).toBe([a, b, c][i]!.userId);
      expect(appt.tokenDate).not.toBeNull();
      expect(appt.queueEntry).toMatchObject({
        organizationId: orgId,
        doctorId: doc.doctorId,
        locationId: loc.id,
        patientId: appt.patientId,
        state: "WAITING",
        tokenNumber: i + 1,
      });
      expect(appt.queueEntry!.queueDate.getTime()).toBe(appt.tokenDate!.getTime());
    }
  }, LONG);
});

describe("§6 ownership is decided server-side, inside the transaction", () => {
  it("A sending B's patientId is refused and consumes nothing; an EXPIRED grant is refused too", async () => {
    const doc = await tokenDoctor();
    const [a, bOwner] = await users(2, "own");
    const pb = await createPatient(orgId, adminUserId, bOwner!.userId);

    const spoof = await book(a!.accessToken, doc.doctorId, { patientId: pb.id });
    expect(spoof.status).toBe(403);
    expect(await db.appointment.count({ where: { patientId: pb.id } })).toBe(0);
    expect(await counter(doc.doctorId)).toBe(0);

    // Guardian WITHOUT a valid grant (expired one).
    const guardian = await registerAndLogin("exp");
    const child = await createPatient(orgId, adminUserId);
    await db.patientAccessGrant.create({
      data: {
        organizationId: orgId,
        patientId: child.id,
        granteeUserId: guardian.userId,
        permissions: ["MANAGE_APPOINTMENTS"],
        grantedById: adminUserId,
        expiresAt: new Date(Date.now() - 60_000),
      },
    });
    expect((await book(guardian.accessToken, doc.doctorId, { patientId: child.id })).status).toBe(403);

    // Guardian with only VIEW (no MANAGE) is refused as well.
    const viewer = await registerAndLogin("viewonly");
    const child2 = await createPatient(orgId, adminUserId);
    await db.patientAccessGrant.create({
      data: { organizationId: orgId, patientId: child2.id, granteeUserId: viewer.userId, permissions: ["VIEW_APPOINTMENTS"], grantedById: adminUserId },
    });
    expect((await book(viewer.accessToken, doc.doctorId, { patientId: child2.id })).status).toBe(403);
    expect(await counter(doc.doctorId)).toBe(0);
  }, LONG);
});

describe("§8 counter scope = organizationId + doctorId + queueDate", () => {
  it("doctor A 1,2,3; doctor B 1,2,3; doctor A tomorrow starts at 1", async () => {
    const docA = await tokenDoctor();
    const docB = await tokenDoctor();
    const us = await users(3, "scope");
    const a = [];
    const b = [];
    for (const u of us) {
      a.push((await book(u.accessToken, docA.doctorId)).body.tokenNumber);
      b.push((await book(u.accessToken, docB.doctorId)).body.tokenNumber);
    }
    expect(a).toEqual([1, 2, 3]);
    expect(b).toEqual([1, 2, 3]);

    // "Tomorrow" can't be reached through the API (server clock), so exercise
    // the allocator with tomorrow's clinic-local date directly.
    const today = (await db.queueEntry.findFirstOrThrow({ where: { doctorId: docA.doctorId } })).queueDate;
    const tomorrow = new Date(today.getTime() + 86_400_000);
    const n = await db.$transaction((tx) =>
      allocateTokenNumber(tx, { organizationId: orgId, doctorId: docA.doctorId, queueDate: tomorrow }),
    );
    expect(n).toBe(1);
    // Today's counter for A is untouched by tomorrow's.
    const rows = await db.queueTokenCounter.findMany({ where: { doctorId: docA.doctorId }, orderBy: { queueDate: "asc" } });
    expect(rows.map((r) => r.lastToken)).toEqual([3, 1]);
  }, LONG);
});

describe("§9 concurrency — 20 patients at the opening minute", () => {
  it("issues exactly 1..20 with no duplicates or gaps", async () => {
    const doc = await tokenDoctor();
    const us = await users(20, "rush");
    const res = await Promise.all(us.map((u) => book(u.accessToken, doc.doctorId)));
    expect(res.map((r) => r.status).sort()).toEqual(Array(20).fill(201));
    const numbers = res.map((r) => r.body.tokenNumber).sort((x, y) => x - y);
    expect(numbers).toEqual(Array.from({ length: 20 }, (_, i) => i + 1));

    const entries = await db.queueEntry.findMany({ where: { doctorId: doc.doctorId }, select: { tokenNumber: true, patientId: true } });
    expect(new Set(entries.map((e) => e.tokenNumber)).size).toBe(20);
    expect(new Set(entries.map((e) => e.patientId)).size).toBe(20);
    expect(await counter(doc.doctorId)).toBe(20);
    expect(await db.appointment.count({ where: { doctorId: doc.doctorId } })).toBe(20);
  }, 600_000);

  it("the daily cap holds under concurrency: cap 5, 10 racing → exactly 5", async () => {
    const doc = await tokenDoctor({ maxDailyTokens: 5 });
    const us = await users(10, "caprace");
    const res = await Promise.all(us.map((u) => book(u.accessToken, doc.doctorId)));
    const ok = res.filter((r) => r.status === 201);
    expect(ok).toHaveLength(5);
    expect(res.filter((r) => r.status === 409).every((r) => r.body.error?.code === "TOKEN_LIMIT_REACHED")).toBe(true);
    expect(await db.queueEntry.count({ where: { doctorId: doc.doctorId } })).toBe(5);
    expect(await counter(doc.doctorId)).toBe(5);
  }, 600_000);
});

describe("§10 maximum daily tokens", () => {
  it("4th is refused with no side effects; raising the cap re-opens booking", async () => {
    const doc = await tokenDoctor({ maxDailyTokens: 3 });
    const us = await users(4, "cap");
    for (const u of us.slice(0, 3)) expect((await book(u.accessToken, doc.doctorId)).status).toBe(201);
    const fourth = await book(us[3]!.accessToken, doc.doctorId);
    expect(fourth.status).toBe(409);
    expect(fourth.body.error?.code).toBe("TOKEN_LIMIT_REACHED");
    expect(await db.appointment.count({ where: { doctorId: doc.doctorId } })).toBe(3);
    expect(await counter(doc.doctorId)).toBe(3);

    const raised = await call(updateDoctorRoute, {
      bearer: adminToken,
      params: { orgId, doctorId: doc.doctorId },
      method: "PATCH",
      body: { maxDailyTokens: 4 },
    });
    expect(raised.status).toBe(200);
    const again = await book(us[3]!.accessToken, doc.doctorId);
    expect(again.status).toBe(201);
    expect(again.body.tokenNumber).toBe(4);
  }, LONG);
});

describe("§12/§15/§16/§17 queue mechanics", () => {
  it("normal flow fills timestamps, writes events/audit, notifies only the patient", async () => {
    const doc = await tokenDoctor();
    const u = await registerAndLogin("normal");
    const t = await book(u.accessToken, doc.doctorId);

    expect((await next(doc.doctorId)).body.tokenNumber).toBe(t.body.tokenNumber);
    await act(t.body.entryId, "start", doc.token);
    await act(t.body.entryId, "complete", doc.token);

    const e = await db.queueEntry.findUniqueOrThrow({ where: { id: t.body.entryId } });
    expect(e.state).toBe("COMPLETED");
    expect(e.calledAt && e.consultationStartedAt && e.completedAt).toBeTruthy();
    const appt = await db.appointment.findUniqueOrThrow({ where: { id: t.body.appointmentId } });
    expect(appt.status).toBe("COMPLETED");
    expect(appt.consultationStartedAt && appt.completedAt).toBeTruthy();

    const events = await db.appointmentEvent.findMany({ where: { appointmentId: appt.id }, orderBy: { at: "asc" } });
    expect(events.map((x) => x.toStatus)).toEqual(["WAITING", "IN_CONSULTATION", "COMPLETED"]);

    const notes = await db.notification.findMany({ where: { event: "QUEUE_UPDATE", userId: u.userId } });
    // WAITING (booked), CALLED, IN_CONSULTATION — COMPLETE is deliberately silent.
    expect(notes.map((n) => (n.payload as { state: string }).state).sort()).toEqual(["CALLED", "IN_CONSULTATION", "WAITING"]);
    for (const n of notes) {
      expect(Object.keys(n.payload as object).sort()).toEqual(["appointmentId", "state", "tokenNumber"]);
    }
  }, LONG);

  it("SKIP then RECALL: served next, token numbers and other positions untouched", async () => {
    const doc = await tokenDoctor();
    const us = await users(4, "skiprc");
    const t = [];
    for (const u of us) t.push((await book(u.accessToken, doc.doctorId)).body);
    const before = await db.queueEntry.findMany({ where: { doctorId: doc.doctorId }, orderBy: { tokenNumber: "asc" } });

    expect((await next(doc.doctorId)).body.tokenNumber).toBe(1);
    expect((await act(t[0]!.entryId, "skip")).body.state).toBe("SKIPPED");
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(2);
    await act(t[1]!.entryId, "start", doc.token);
    await act(t[1]!.entryId, "complete", doc.token);

    const recalled = await act(t[0]!.entryId, "recall");
    expect(recalled.body).toMatchObject({ state: "WAITING", tokenNumber: 1, position: -1 });
    // Recalled patient beats #3 and #4.
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(1);

    const after = await db.queueEntry.findMany({ where: { doctorId: doc.doctorId }, orderBy: { tokenNumber: "asc" } });
    expect(after.map((e) => e.tokenNumber)).toEqual(before.map((e) => e.tokenNumber));
    expect(after.slice(2).map((e) => e.position)).toEqual(before.slice(2).map((e) => e.position));
    expect(after[0]!.recallCount).toBe(1);
  }, LONG);

  it("NO_SHOW is final: cannot call, start, complete or recall; stays in history", async () => {
    const doc = await tokenDoctor();
    const u = await registerAndLogin("noshowqa");
    const t = await book(u.accessToken, doc.doctorId);
    await next(doc.doctorId);
    expect((await act(t.body.entryId, "no-show")).body.state).toBe("NO_SHOW");

    for (const [a, who] of [["call", adminToken], ["start", doc.token], ["complete", doc.token], ["recall", adminToken], ["hold", adminToken]] as const) {
      expect((await act(t.body.entryId, a, who)).status).toBe(409);
    }
    const bd = await board(doc.doctorId);
    const row = bd.body.entries.find((e) => e.id === t.body.entryId)!;
    expect(row.state).toBe("NO_SHOW");
    expect(row.actions).toEqual([]);
    expect(bd.body.summary.noShow).toBe(1);
    expect((await db.appointment.findUniqueOrThrow({ where: { id: t.body.appointmentId } })).status).toBe("NO_SHOW");
    // Not served by call-next.
    expect((await next(doc.doctorId)).status).toBe(409);
  }, LONG);
});

describe("§19 closing only stops NEW tokens", () => {
  it("after the window closes, existing tokens are still called, consulted and completed", async () => {
    const doc = await tokenDoctor();
    const [a, late] = await users(2, "close");
    const t = await book(a!.accessToken, doc.doctorId);

    const now = localMinuteNow(new Date(), tz);
    if (now < 2) return; // can't express "closed already" in the first minute of the day
    await setTokenWindow(orgId, doc.doctorId, {
      bookingMode: "BOTH",
      tokenOpensMinute: 0,
      tokenClosesMinute: now - 1,
      queueStartMinute: 0,
      maxDailyTokens: 50,
    });
    const refused = await book(late!.accessToken, doc.doctorId);
    expect(refused.body.error?.code).toBe("TOKEN_BOOKING_CLOSED");

    expect((await next(doc.doctorId)).body.tokenNumber).toBe(t.body.tokenNumber);
    expect((await act(t.body.entryId, "start", doc.token)).body.state).toBe("IN_CONSULTATION");
    expect((await act(t.body.entryId, "complete", doc.token)).body.state).toBe("COMPLETED");
  }, LONG);
});

describe("§21/§22/§23 privacy, tenancy, doctor scope — direct API", () => {
  it("patient A cannot read, cancel, hold or recall patient B's token, nor read the board", async () => {
    const doc = await tokenDoctor();
    const [a, b] = await users(2, "priv");
    await book(a!.accessToken, doc.doctorId);
    const tb = await book(b!.accessToken, doc.doctorId);

    expect((await status(a!.accessToken, tb.body.appointmentId)).status).toBe(404);
    expect([403, 404]).toContain((await apptRoute(cancelRoute, tb.body.appointmentId, a!.accessToken, { reason: "x" })).status);
    expect((await act(tb.body.entryId, "hold", a!.accessToken)).status).toBe(403);
    expect((await act(tb.body.entryId, "recall", a!.accessToken)).status).toBe(403);
    expect((await board(doc.doctorId, a!.accessToken)).status).toBe(403);
    const entry = await db.queueEntry.findUniqueOrThrow({ where: { id: tb.body.entryId } });
    expect(entry.state).toBe("WAITING");
  }, LONG);

  it("clinic B cannot read or operate clinic A's queue or appointments", async () => {
    const doc = await tokenDoctor();
    const u = await registerAndLogin("tenA");
    const t = await book(u.accessToken, doc.doctorId);

    const bAdmin = await registerAndLogin("tenBadm");
    const orgB = (await createOrg(bAdmin.accessToken, "clinicb")).id;
    const bPatient = await registerAndLogin("tenBpat");

    expect([403, 404]).toContain((await board(doc.doctorId, bAdmin.accessToken, orgId)).status);
    expect((await board(doc.doctorId, bAdmin.accessToken, orgB)).status).toBe(404);
    for (const a of ["call", "hold", "recall", "skip", "release", "no-show"]) {
      expect([403, 404]).toContain((await act(t.body.entryId, a, bAdmin.accessToken, orgId)).status);
      expect((await act(t.body.entryId, a, bAdmin.accessToken, orgB)).status).toBe(404);
    }
    expect((await apptRoute(cancelRoute, t.body.appointmentId, bAdmin.accessToken, { reason: "x" }, orgB)).status).toBe(404);
    expect((await status(bPatient.accessToken, t.body.appointmentId)).status).toBe(404);
    expect((await db.queueEntry.findUniqueOrThrow({ where: { id: t.body.entryId } })).state).toBe("WAITING");
  }, LONG);

  it("doctor B can do none of call/next/hold/release/skip/recall/no-show on doctor A's queue", async () => {
    const docA = await tokenDoctor();
    const docB = await createDoctorWithLogin(adminToken, orgId);
    const us = await users(2, "docscope");
    const t1 = await book(us[0]!.accessToken, docA.doctorId);
    const t2 = await book(us[1]!.accessToken, docA.doctorId);
    await act(t2.body.entryId, "hold"); // so release/recall have a legal source state

    expect((await next(docA.doctorId, docB.token)).status).toBe(403);
    for (const [entry, a] of [[t1, "call"], [t1, "skip"], [t1, "hold"], [t1, "no-show"], [t2, "release"], [t2, "recall"]] as const) {
      expect((await act(entry.body.entryId, a, docB.token)).status).toBe(403);
    }
    // And doctor A can, on their own queue.
    expect((await act(t2.body.entryId, "release", docA.token)).status).toBe(200);
    expect((await next(docA.doctorId, docA.token)).status).toBe(200);
  }, LONG);
});

describe("§25 changing booking mode never rewrites existing appointments", () => {
  it("tokens stay tokens and stay operable after the doctor switches to SCHEDULED", async () => {
    const doc = await tokenDoctor();
    const u = await registerAndLogin("modechg");
    const t = await book(u.accessToken, doc.doctorId);
    const res = await call(updateDoctorRoute, {
      bearer: adminToken,
      params: { orgId, doctorId: doc.doctorId },
      method: "PATCH",
      body: { bookingMode: "SCHEDULED" },
    });
    expect(res.status).toBe(200);
    expect((await db.appointment.findUniqueOrThrow({ where: { id: t.body.appointmentId } })).bookingKind).toBe("SAME_DAY_TOKEN");
    expect((await book((await registerAndLogin("modechg2")).accessToken, doc.doctorId)).body.error?.code).toBe(
      "TOKEN_BOOKING_UNAVAILABLE",
    );
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(t.body.tokenNumber);
  }, LONG);
});

describe("§32 cancellation — documents the EXISTING policy", () => {
  it("patient self-cancel is subject to the clinic's cancellation window, measured from queue start", async () => {
    const now = localMinuteNow(new Date(), tz);
    // Queue start = right now → inside the default 4h window → refused.
    const doc = await tokenDoctor({ queueStartMinute: now });
    const u = await registerAndLogin("pcancel");
    const t = await book(u.accessToken, doc.doctorId);
    const res = await apptRoute(cancelRoute, t.body.appointmentId, u.accessToken, { reason: "can't come" });
    // Existing mapping: OUTSIDE_CANCELLATION_WINDOW is a 403 (src/lib/errors.ts).
    expect(res.status, JSON.stringify(res.body)).toBe(403);
    expect(res.body.error?.code).toBe("OUTSIDE_CANCELLATION_WINDOW");

    // With the clinic's window set to 0h the same patient may cancel.
    await db.clinicSettings.update({ where: { organizationId: orgId }, data: { cancellationWindowHours: 0 } });
    try {
      // Anchor must still be in the future for a 0h window.
      // Anchor 10 minutes ahead: the test's own setup takes ~30-40 s remotely.
      if (now < 1429) {
        const doc2 = await tokenDoctor({ queueStartMinute: now + 10 });
        const u2 = await registerAndLogin("pcancel2");
        const t2 = await book(u2.accessToken, doc2.doctorId);
        const ok = await apptRoute(cancelRoute, t2.body.appointmentId, u2.accessToken, { reason: "can't come" });
        expect(ok.status, JSON.stringify(ok.body)).toBe(200);
        expect((await status(u2.accessToken, t2.body.appointmentId)).body.appointmentStatus).toBe("CANCELLED");
      }
    } finally {
      await db.clinicSettings.update({ where: { organizationId: orgId }, data: { cancellationWindowHours: 4 } });
    }
  }, LONG);

  it("staff can cancel a CALLED or HELD token; the entry can never be recalled back to life", async () => {
    const doc = await tokenDoctor();
    const [a, b] = await users(2, "scancel");
    const ta = await book(a!.accessToken, doc.doctorId);
    const tb = await book(b!.accessToken, doc.doctorId);
    await next(doc.doctorId); // #a CALLED
    await act(tb.body.entryId, "hold");

    for (const t of [ta, tb]) {
      expect((await apptRoute(cancelRoute, t.body.appointmentId, adminToken, { reason: "left" })).status).toBe(200);
      const entry = await db.queueEntry.findUniqueOrThrow({ where: { id: t.body.entryId } });
      expect(entry.state).toBe("SKIPPED");
      // Regression: RECALL used to resurrect a cancelled appointment via START.
      expect((await act(t.body.entryId, "recall")).status).toBe(409);
      expect((await db.appointment.findUniqueOrThrow({ where: { id: t.body.appointmentId } })).status).toBe("CANCELLED");
    }
    const bd = await board(doc.doctorId);
    expect(bd.body.entries.every((e) => e.actions.length === 0)).toBe(true);
    // Patient's view shows the cancellation, not "you missed your call".
    const s = await status(a!.accessToken, ta.body.appointmentId);
    expect(s.body.appointmentStatus).toBe("CANCELLED");
    expect(s.body.advice).toMatch(/cancelled/i);
  }, LONG);

  it("in-consultation, completed and no-show tokens cannot be cancelled", async () => {
    const doc = await tokenDoctor();
    const us = await users(3, "nocancel");
    const t = [];
    for (const u of us) t.push((await book(u.accessToken, doc.doctorId)).body);
    await act(t[0]!.entryId, "call");
    await act(t[0]!.entryId, "start", doc.token); // IN_CONSULTATION
    await act(t[2]!.entryId, "no-show"); // NO_SHOW
    expect((await apptRoute(cancelRoute, t[0]!.appointmentId, adminToken, { reason: "x" })).status).toBe(409);
    await act(t[0]!.entryId, "complete", doc.token); // COMPLETED
    expect((await apptRoute(cancelRoute, t[0]!.appointmentId, adminToken, { reason: "x" })).status).toBe(409);
    expect((await apptRoute(cancelRoute, t[2]!.appointmentId, adminToken, { reason: "x" })).status).toBe(409);
    expect((await db.queueEntry.findUniqueOrThrow({ where: { id: t[2]!.entryId } })).state).toBe("NO_SHOW");
  }, LONG);
});

describe("§33 the consultation page path keeps the queue in step", () => {
  it("token → call → consultation-page start → SOAP → Rx → sign → complete; call-next keeps working", async () => {
    const doc = await tokenDoctor();
    const [a, b] = await users(2, "soap");
    const ta = await book(a!.accessToken, doc.doctorId);
    const tb = await book(b!.accessToken, doc.doctorId);
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(1);

    // The consultation page uses the APPOINTMENT routes, not the queue ones.
    expect((await apptRoute(startApptRoute, ta.body.appointmentId, doc.token)).status).toBe(200);
    expect((await db.queueEntry.findUniqueOrThrow({ where: { id: ta.body.entryId } })).state).toBe("IN_CONSULTATION");

    expect(
      (await call(saveConsultationRoute, {
        bearer: doc.token,
        params: { orgId, appointmentId: ta.body.appointmentId },
        method: "PUT",
        body: { subjective: "Fever 2 days", assessment: "Viral fever", plan: "Rest" },
      })).status,
    ).toBe(200);
    expect(
      (await call(addItemRoute, {
        bearer: doc.token,
        params: { orgId, appointmentId: ta.body.appointmentId },
        body: { drugName: "Paracetamol", dosage: "500 mg", frequency: "Thrice daily", durationDays: 3 },
      })).status,
    ).toBe(201);
    expect((await apptRoute(signRoute, ta.body.appointmentId, doc.token)).status).toBe(200);
    expect((await apptRoute(completeApptRoute, ta.body.appointmentId, doc.token)).status).toBe(200);

    const entry = await db.queueEntry.findUniqueOrThrow({ where: { id: ta.body.entryId } });
    expect(entry.state).toBe("COMPLETED");
    expect(entry.completedAt).not.toBeNull();
    // Regression: this used to 409 "Someone is already called" all day.
    const n = await next(doc.doctorId);
    expect(n.status).toBe(200);
    expect(n.body.tokenNumber).toBe(tb.body.tokenNumber);
    expect((await status(a!.accessToken, ta.body.appointmentId)).body.state).toBe("COMPLETED");
  }, LONG);
});

describe("§31 one journey's audit trail, and polling writes nothing", () => {
  it("BOOK → CALL → HOLD → RECALL(→CALLED) → START → COMPLETE, each recorded once", async () => {
    const doc = await tokenDoctor();
    const u = await registerAndLogin("trail");
    const t = await book(u.accessToken, doc.doctorId);
    await next(doc.doctorId);
    await act(t.body.entryId, "hold");
    await act(t.body.entryId, "recall");
    await act(t.body.entryId, "start", doc.token);
    await act(t.body.entryId, "complete", doc.token);

    const snapshot = async () => ({
      audit: await db.auditLog.findMany({
        where: { entityId: { in: [t.body.entryId, t.body.appointmentId] } },
        orderBy: { at: "asc" },
        select: { action: true },
      }),
      events: await db.appointmentEvent.count({ where: { appointmentId: t.body.appointmentId } }),
      notes: await db.notification.count({ where: { userId: u.userId } }),
    });
    const s1 = await snapshot();
    expect(s1.audit.map((x) => x.action)).toEqual([
      "TOKEN_BOOKED",
      "QUEUE_CALL",
      "QUEUE_HOLD",
      "QUEUE_RECALL",
      "QUEUE_START",
      "QUEUE_COMPLETE",
    ]);
    expect(s1.events).toBe(3); // WAITING (token:book), IN_CONSULTATION, COMPLETED

    // Polling (status + board) is read-only.
    for (let i = 0; i < 3; i++) {
      await status(u.accessToken, t.body.appointmentId);
      await board(doc.doctorId);
    }
    expect(await snapshot()).toEqual(s1);
  }, LONG);
});

describe("§39 final acceptance — Dr. Sharma, ABC Clinic, BOTH, A/B/C/D", () => {
  it("runs the morning and every view agrees at the end", async () => {
    const doc = await tokenDoctor({ tokenOpensMinute: 0, tokenClosesMinute: 1439, queueStartMinute: 540, maxDailyTokens: 50 });
    const [A, B, C, D] = await users(4, "final");
    const t: TokenResult[] = [];
    for (const u of [A, B, C, D]) t.push((await book(u!.accessToken, doc.doctorId)).body);
    expect(t.map((x) => x.tokenNumber)).toEqual([1, 2, 3, 4]);

    // #1: called → in consultation → completed
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(1);
    await act(t[0]!.entryId, "start", doc.token);
    await act(t[0]!.entryId, "complete", doc.token);
    // #2: called, does not arrive → HOLD
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(2);
    expect((await act(t[1]!.entryId, "hold")).body.state).toBe("HOLD");
    // Call next → #3 (not #2)
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(3);
    await act(t[2]!.entryId, "start", doc.token);
    await act(t[2]!.entryId, "complete", doc.token);
    // B arrives → recall #2 → CALLED directly (HOLD recall = "call them again")
    const rec = await act(t[1]!.entryId, "recall");
    expect(rec.body).toMatchObject({ state: "CALLED", tokenNumber: 2 });
    await act(t[1]!.entryId, "start", doc.token);
    await act(t[1]!.entryId, "complete", doc.token);

    const bd = await board(doc.doctorId, doc.token);
    const by = (s: string) => bd.body.entries.filter((e) => e.state === s).map((e) => e.tokenNumber);
    expect(by("COMPLETED").sort()).toEqual([1, 2, 3]);
    expect(by("WAITING")).toEqual([4]);
    expect(by("HOLD")).toEqual([]);
    expect(bd.body.summary).toMatchObject({ completed: 3, waiting: 1, onHold: 0, total: 4 });

    const views = await Promise.all([A, B, C, D].map((u, i) => status(u!.accessToken, t[i]!.appointmentId)));
    expect(views.map((v) => v.body.state)).toEqual(["COMPLETED", "COMPLETED", "COMPLETED", "WAITING"]);
    expect(views[3]!.body.ahead).toBe(0);
  }, 600_000);
});
