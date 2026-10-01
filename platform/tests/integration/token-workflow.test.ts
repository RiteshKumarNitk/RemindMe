/**
 * Same-day token workflow — the end-to-end reception scenario plus the RBAC and
 * tenant-isolation edges around it (TOKEN_BOOKING_ASSESSMENT.md).
 *
 * Complements token-booking.test.ts (booking rules, window, cap, concurrency)
 * by driving the queue the way a clinic actually runs it.
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
import { GET as tokenStatusRoute } from "../../app/api/patient/token-status/route.js";
import { POST as walkInRoute } from "../../app/api/orgs/[orgId]/queue/walk-in/route.js";
import { POST as nextRoute } from "../../app/api/orgs/[orgId]/queue/next/route.js";
import { GET as boardRoute } from "../../app/api/orgs/[orgId]/queue/route.js";
import { POST as queueActionRoute } from "../../app/api/orgs/[orgId]/queue/[entryId]/[action]/route.js";
import { GET as listAppointmentsRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { PATCH as updateDoctorRoute } from "../../app/api/orgs/[orgId]/doctors/[doctorId]/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;

interface TokenResult {
  appointmentId: string;
  entryId: string;
  tokenNumber: number;
  reused: boolean;
}
type BoardEntry = { id: string; tokenNumber: number; state: string; actions: string[] };
type Board = { summary: Record<string, number>; nowServingToken: number | null; entries: BoardEntry[] };

const DEMO = { firstName: "Flow", lastName: "Tester" };

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("twadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "tokenflow")).id;
  await publishOrgForDiscovery(adminToken, orgId);
});

afterAll(disconnect);

async function tokenDoctor(mode: "SAME_DAY_TOKEN" | "BOTH" = "BOTH") {
  const doc = await createDoctorWithLogin(adminToken, orgId);
  await makeDoctorPublic(adminToken, orgId, doc.doctorId);
  await setTokenWindow(orgId, doc.doctorId, { ...alwaysOpenWindow(), bookingMode: mode });
  return doc;
}

const book = (bearer: string, doctorId: string, extra: Record<string, unknown> = {}) =>
  call<TokenResult>(tokenRoute, {
    bearer,
    params: {},
    body: { organizationId: orgId, doctorId, patient: DEMO, ...extra },
  });

const act = (entryId: string, action: string, bearer = adminToken, org = orgId) =>
  call<{ state: string; tokenNumber: number }>(queueActionRoute, {
    bearer,
    params: { orgId: org, entryId, action },
  });

const next = (doctorId: string, bearer = adminToken) =>
  call<{ state: string; tokenNumber: number; id: string }>(nextRoute, {
    bearer,
    params: { orgId },
    url: `http://x/api?doctorId=${doctorId}`,
  });

const board = (doctorId: string, bearer = adminToken) =>
  call<Board>(boardRoute, { bearer, params: { orgId }, url: `http://x/api?doctorId=${doctorId}` });

const status = (bearer: string, appointmentId: string) =>
  call<{ state: string; tokenNumber: number; ahead: number }>(tokenStatusRoute, {
    bearer,
    url: `http://x/api?appointmentId=${appointmentId}`,
  });

describe("acceptance: Dr. Sharma, BOTH, tokens 1-3 with a hold and a recall", () => {
  it("runs the whole clinic morning and every view agrees", async () => {
    const doc = await tokenDoctor("BOTH");
    const [a, b, c] = await Promise.all([
      registerAndLogin("pa"),
      registerAndLogin("pb"),
      registerAndLogin("pc"),
    ]);

    // 07:00 — three patients book in order.
    const ta = await book(a.accessToken, doc.doctorId);
    const tb = await book(b.accessToken, doc.doctorId);
    const tc = await book(c.accessToken, doc.doctorId);
    expect([ta.status, tb.status, tc.status]).toEqual([201, 201, 201]);
    expect([ta.body.tokenNumber, tb.body.tokenNumber, tc.body.tokenNumber]).toEqual([1, 2, 3]);

    // Reception sees 1 A, 2 B, 3 C — all waiting.
    let bd = await board(doc.doctorId);
    expect(bd.body.entries.map((e) => [e.tokenNumber, e.state])).toEqual([
      [1, "WAITING"],
      [2, "WAITING"],
      [3, "WAITING"],
    ]);

    // Call #1 → A arrives → consultation → completed.
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(1);
    expect((await act(ta.body.entryId, "start", doc.token)).body.state).toBe("IN_CONSULTATION");
    expect((await act(ta.body.entryId, "complete", doc.token)).body.state).toBe("COMPLETED");

    // Call #2 → B does not answer → HOLD (straight from CALLED).
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(2);
    expect((await act(tb.body.entryId, "hold")).body.state).toBe("HOLD");

    // Call next skips the held #2 and picks #3 → C arrives → consultation.
    expect((await next(doc.doctorId)).body.tokenNumber).toBe(3);
    expect((await act(tc.body.entryId, "start", doc.token)).body.state).toBe("IN_CONSULTATION");

    // Later B arrives → recall #2 → back to CALLED.
    expect((await act(tb.body.entryId, "recall")).body.state).toBe("CALLED");

    // Doctor dashboard (same board, read as the doctor).
    bd = await board(doc.doctorId, doc.token);
    expect(bd.status).toBe(200);
    expect(bd.body.summary).toMatchObject({ completed: 1, inConsultation: 1, called: 1, onHold: 0, total: 3 });
    expect(bd.body.nowServingToken).toBe(3);

    // Each patient sees their own real state.
    expect((await status(a.accessToken, ta.body.appointmentId)).body.state).toBe("COMPLETED");
    expect((await status(b.accessToken, tb.body.appointmentId)).body.state).toBe("CALLED");
    expect((await status(c.accessToken, tc.body.appointmentId)).body.state).toBe("IN_CONSULTATION");

    // A cannot read B's token.
    expect((await status(a.accessToken, tb.body.appointmentId)).status).toBe(404);

    // Clinic admin's appointment list shows the same three appointments —
    // no second token table.
    const list = await call<{ data: Array<{ id: string; bookingKind: string }> }>(listAppointmentsRoute, {
      bearer: adminToken,
      params: { orgId },
      url: `http://x/api?doctorId=${doc.doctorId}&limit=50`,
    });
    const ids = list.body.data.map((r) => r.id).sort();
    expect(ids).toEqual([ta.body.appointmentId, tb.body.appointmentId, tc.body.appointmentId].sort());
    expect(list.body.data.every((r) => r.bookingKind === "SAME_DAY_TOKEN")).toBe(true);

    // Every step is in the existing event / audit trail.
    const audit = await db.auditLog.findMany({
      where: { organizationId: orgId, entityId: { in: [ta.body.entryId, tb.body.entryId, tc.body.entryId] } },
      select: { action: true },
    });
    const actions = new Set(audit.map((x) => x.action));
    for (const a of ["QUEUE_CALL", "QUEUE_START", "QUEUE_COMPLETE", "QUEUE_HOLD", "QUEUE_RECALL"]) {
      expect(actions.has(a)).toBe(true);
    }
    const booked = await db.appointmentEvent.count({
      where: { appointmentId: { in: [ta.body.appointmentId, tb.body.appointmentId, tc.body.appointmentId] }, reason: "token:book" },
    });
    expect(booked).toBe(3);
  }, 240_000);
});

describe("token booking never trusts client-supplied ids", () => {
  it("a patient cannot take a token in someone else's name", async () => {
    const doc = await tokenDoctor();
    const victimOwner = await registerAndLogin("victim");
    const victim = await createPatient(orgId, adminUserId, victimOwner.userId);
    const attacker = await registerAndLogin("spoof");

    const res = await book(attacker.accessToken, doc.doctorId, { patientId: victim.id });
    expect(res.status).toBe(403);
    expect(await db.appointment.count({ where: { patientId: victim.id } })).toBe(0);
  }, 120_000);

  it("a guardian with MANAGE_APPOINTMENTS may book for the dependent", async () => {
    const doc = await tokenDoctor();
    const guardian = await registerAndLogin("guard");
    const child = await createPatient(orgId, adminUserId);
    await db.patientAccessGrant.create({
      data: {
        organizationId: orgId,
        patientId: child.id,
        granteeUserId: guardian.userId,
        permissions: ["VIEW_APPOINTMENTS", "MANAGE_APPOINTMENTS"],
        grantedById: adminUserId,
      },
    });
    const res = await book(guardian.accessToken, doc.doctorId, { patientId: child.id });
    expect(res.status).toBe(201);
    const appt = await db.appointment.findUniqueOrThrow({ where: { id: res.body.appointmentId } });
    expect(appt.patientId).toBe(child.id);
  }, 120_000);

  it("a location from another clinic is refused", async () => {
    const doc = await tokenDoctor();
    const other = await createOrg(adminToken, "foreignloc");
    const loc = await db.clinicLocation.create({
      data: { organizationId: other.id, name: "Elsewhere" },
      select: { id: true },
    });
    const u = await registerAndLogin("locspoof");
    const res = await book(u.accessToken, doc.doctorId, { locationId: loc.id });
    expect(res.status).toBe(404);
  }, 120_000);
});

describe("queue RBAC", () => {
  it("another doctor cannot work this doctor's queue, and is not offered the buttons", async () => {
    const doc = await tokenDoctor();
    const otherDoc = await createDoctorWithLogin(adminToken, orgId);
    const u = await registerAndLogin("rbac1");
    const t = await book(u.accessToken, doc.doctorId);

    expect((await act(t.body.entryId, "hold", otherDoc.token)).status).toBe(403);
    expect((await act(t.body.entryId, "call", otherDoc.token)).status).toBe(403);

    const bd = await board(doc.doctorId, otherDoc.token);
    const row = bd.body.entries.find((e) => e.id === t.body.entryId)!;
    expect(row.actions).toEqual([]);
  }, 120_000);

  it("a patient cannot drive the queue", async () => {
    const doc = await tokenDoctor();
    const u = await registerAndLogin("rbac2");
    const t = await book(u.accessToken, doc.doctorId);
    // The patient is a member of this org (self-enrolled), so this is a role
    // refusal, not a tenancy one.
    expect((await act(t.body.entryId, "call", u.accessToken)).status).toBe(403);
    expect((await next(doc.doctorId, u.accessToken)).status).toBe(403);
  }, 120_000);

  it("another clinic's admin cannot touch this clinic's queue entry", async () => {
    const doc = await tokenDoctor();
    const u = await registerAndLogin("xten");
    const t = await book(u.accessToken, doc.doctorId);

    const otherAdmin = await registerAndLogin("xadm");
    const otherOrg = await createOrg(otherAdmin.accessToken, "xclinic");
    // Via their own org id: the entry does not exist there.
    expect((await act(t.body.entryId, "hold", otherAdmin.accessToken, otherOrg.id)).status).toBe(404);
    // Via this org's id: not a member.
    const res = await act(t.body.entryId, "hold", otherAdmin.accessToken, orgId);
    expect([403, 404]).toContain(res.status);
    const entry = await db.queueEntry.findUniqueOrThrow({ where: { id: t.body.entryId } });
    expect(entry.state).toBe("WAITING");
  }, 120_000);

  it("a doctor can only issue walk-in tokens for their own queue", async () => {
    const doc = await tokenDoctor();
    const otherDoc = await createDoctorWithLogin(adminToken, orgId);
    const patient = await createPatient(orgId, adminUserId);
    const res = await call(walkInRoute, {
      bearer: otherDoc.token,
      params: { orgId },
      url: `http://x/api?doctorId=${doc.doctorId}`,
      body: { patientId: patient.id },
    });
    expect(res.status).toBe(403);
  }, 120_000);
});

describe("booking preference validation", () => {
  const patch = (doctorId: string, body: Record<string, unknown>, bearer = adminToken) =>
    call(updateDoctorRoute, { bearer, params: { orgId, doctorId }, body, method: "PATCH" });

  it("refuses a window that closes before it opens", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    const res = await patch(doc.doctorId, {
      bookingMode: "SAME_DAY_TOKEN",
      tokenOpensMinute: 660,
      tokenClosesMinute: 420,
    });
    expect(res.status).toBe(422);
  }, 60_000);

  it("validates a partial change against the stored window", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    // Stored defaults: opens 07:00, closes 11:00, queue 09:00. Moving only the
    // close to 06:00 must fail even though the request itself has one field.
    const res = await patch(doc.doctorId, { tokenClosesMinute: 360 });
    expect(res.status).toBe(422);
  }, 60_000);

  it("the doctor may set their own mode and window; 7:00 is not hardcoded", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    const res = await patch(
      doc.doctorId,
      { bookingMode: "BOTH", tokenOpensMinute: 360, tokenClosesMinute: 600, queueStartMinute: 480, maxDailyTokens: 30 },
      doc.token,
    );
    expect(res.status).toBe(200);
    const row = await db.doctorProfile.findUniqueOrThrow({ where: { id: doc.doctorId } });
    expect(row).toMatchObject({ bookingMode: "BOTH", tokenOpensMinute: 360, maxDailyTokens: 30 });
  }, 60_000);

  it("another doctor cannot change this doctor's booking mode", async () => {
    const doc = await createDoctorWithLogin(adminToken, orgId);
    const other = await createDoctorWithLogin(adminToken, orgId);
    const res = await patch(doc.doctorId, { bookingMode: "SAME_DAY_TOKEN" }, other.token);
    expect(res.status).toBe(403);
  }, 60_000);
});
