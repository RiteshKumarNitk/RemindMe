import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import {
  createDoctorWithLogin,
  createOrg,
  createPatient,
  firstSlot,
  registerAndLogin,
  setWeeklyAvailability,
} from "../helpers/factories.js";
import { POST as bookRoute, GET as listRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { GET as getRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/route.js";
import { POST as confirmRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/confirm/route.js";
import { POST as cancelRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/cancel/route.js";
import { POST as rescheduleRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/reschedule/route.js";
import { POST as checkInRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/check-in/route.js";
import { POST as noShowRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/no-show/route.js";
import { POST as startRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/start/route.js";
import { POST as completeRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/complete/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;
let doctorId: string;
let doctorToken: string;
let patientId: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("apadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "appt")).id;
  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  doctorToken = doc.token;
  await setWeeklyAvailability(adminToken, orgId, doctorId, { slotMinutes: 15 });
  patientId = (await createPatient(orgId, admin.userId)).id;
});
afterAll(disconnect);

async function book(daysAhead = 7) {
  const slot = await firstSlot(adminToken, orgId, doctorId, daysAhead);
  const res = await call<{ id: string; status: string; scheduledEnd: string }>(bookRoute, {
    bearer: adminToken,
    params: { orgId },
    body: { patientId, doctorId, scheduledStart: slot.start },
  });
  return { res, slot };
}

describe("appointment lifecycle (APPOINTMENT_WORKFLOW.md)", () => {
  it("staff booking → CONFIRMED, with a null→CONFIRMED event + audit", async () => {
    const { res } = await book(7);
    expect(res.status).toBe(201);
    expect(res.body.status).toBe("CONFIRMED");

    const full = await call<{ events: Array<{ toStatus: string }> }>(getRoute, {
      bearer: adminToken,
      params: { orgId, appointmentId: res.body.id },
    });
    expect(full.body.events.map((e) => e.toStatus)).toEqual(["CONFIRMED"]);
    const audit = await db.auditLog.findFirst({
      where: { organizationId: orgId, action: "APPOINTMENT_CREATED", entityId: res.body.id },
    });
    expect(audit).not.toBeNull();
  });

  it("booking outside availability → 409 OUTSIDE_AVAILABILITY", async () => {
    // 03:00 UTC on a far date is outside 09:00–17:00 local everywhere sane.
    const date = new Date(Date.now() + 8 * 86_400_000).toISOString().slice(0, 10);
    const res = await call(bookRoute, {
      bearer: adminToken,
      params: { orgId },
      body: { patientId, doctorId, scheduledStart: `${date}T03:00:00.000Z` },
    });
    expect(res.status).toBe(409);
    expect((res.body as { error: { code: string } }).error.code).toBe("OUTSIDE_AVAILABILITY");
  });

  it("double-booking the same slot → second is 409 APPOINTMENT_SLOT_TAKEN", async () => {
    const slot = await firstSlot(adminToken, orgId, doctorId, 9);
    const p2 = await createPatient(orgId, adminUserId);
    const [a, b] = await Promise.all([
      call(bookRoute, {
        bearer: adminToken,
        params: { orgId },
        body: { patientId, doctorId, scheduledStart: slot.start },
      }),
      call(bookRoute, {
        bearer: adminToken,
        params: { orgId },
        body: { patientId: p2.id, doctorId, scheduledStart: slot.start },
      }),
    ]);
    const codes = [a.status, b.status].sort();
    expect(codes).toEqual([201, 409]);
    const failed = a.status === 409 ? a : b;
    expect((failed.body as { error: { code: string } }).error.code).toBe("APPOINTMENT_SLOT_TAKEN");
  });

  it("full flow: confirm → check-in (token) → start → complete", async () => {
    const { res } = await book(10);
    const id = res.body.id;

    // already CONFIRMED (staff book) — check-in directly.
    const checkedIn = await call<{ appointment: { status: string }; queue: { tokenNumber: number } }>(
      checkInRoute,
      { bearer: adminToken, params: { orgId, appointmentId: id } },
    );
    expect(checkedIn.status).toBe(200);
    expect(checkedIn.body.appointment.status).toBe("WAITING");
    expect(checkedIn.body.queue.tokenNumber).toBeGreaterThanOrEqual(1);

    const started = await call<{ status: string }>(startRoute, {
      bearer: doctorToken,
      params: { orgId, appointmentId: id },
    });
    expect(started.status).toBe(200);
    expect(started.body.status).toBe("IN_CONSULTATION");

    const completed = await call<{ status: string }>(completeRoute, {
      bearer: doctorToken,
      params: { orgId, appointmentId: id },
    });
    expect(completed.body.status).toBe("COMPLETED");
  });

  it("invalid transition → 409 INVALID_STATUS_TRANSITION", async () => {
    const { res } = await book(11);
    // Can't complete a CONFIRMED appointment.
    const bad = await call(completeRoute, {
      bearer: doctorToken,
      params: { orgId, appointmentId: res.body.id },
    });
    expect(bad.status).toBe(409);
    expect((bad.body as { error: { code: string } }).error.code).toBe("INVALID_STATUS_TRANSITION");
  });

  it("only the assigned doctor can start/complete", async () => {
    const { res } = await book(12);
    await call(checkInRoute, { bearer: adminToken, params: { orgId, appointmentId: res.body.id } });
    const otherDoc = await createDoctorWithLogin(adminToken, orgId);
    const bad = await call(startRoute, {
      bearer: otherDoc.token,
      params: { orgId, appointmentId: res.body.id },
    });
    expect(bad.status).toBe(403);
  });

  it("no-show only from CONFIRMED and not before the appointment time", async () => {
    const { res } = await book(13);
    const early = await call(noShowRoute, {
      bearer: adminToken,
      params: { orgId, appointmentId: res.body.id },
    });
    expect(early.status).toBe(409); // before scheduledStart
  });

  it("reschedule creates a linked new appointment; old → RESCHEDULED", async () => {
    const { res } = await book(14);
    const newSlot = await firstSlot(adminToken, orgId, doctorId, 15);
    const rescheduled = await call<{ previousId: string; appointment: { id: string; status: string; rescheduledFromId: string } }>(
      rescheduleRoute,
      {
        bearer: adminToken,
        params: { orgId, appointmentId: res.body.id },
        body: { scheduledStart: newSlot.start },
      },
    );
    expect(rescheduled.status).toBe(201);
    expect(rescheduled.body.appointment.rescheduledFromId).toBe(res.body.id);
    const old = await call<{ status: string }>(getRoute, {
      bearer: adminToken,
      params: { orgId, appointmentId: res.body.id },
    });
    expect(old.body.status).toBe("RESCHEDULED");
  });

  it("patient self-cancel is blocked inside the cancellation window (staff can override)", async () => {
    const patUser = await registerAndLogin("selfpat");
    await db.membership.create({
      data: { userId: patUser.userId, organizationId: orgId, role: "PATIENT", status: "ACTIVE" },
    });
    const selfPatient = await createPatient(orgId, patUser.userId, patUser.userId);

    // Seed an appointment 2h out directly (default cancellation window = 4h).
    const start = new Date(Date.now() + 2 * 3600_000);
    const appt = await db.appointment.create({
      data: {
        organizationId: orgId,
        patientId: selfPatient.id,
        doctorId,
        scheduledStart: start,
        scheduledEnd: new Date(start.getTime() + 15 * 60_000),
        timezone: "Asia/Kolkata",
        status: "CONFIRMED",
        bookingSource: "RECEPTION",
        createdById: patUser.userId,
        confirmedAt: new Date(),
      },
      select: { id: true },
    });

    const patientCancel = await call(cancelRoute, {
      bearer: patUser.accessToken,
      params: { orgId, appointmentId: appt.id },
      body: { reason: "changed my mind" },
    });
    expect(patientCancel.status).toBe(403);
    expect((patientCancel.body as { error: { code: string } }).error.code).toBe(
      "OUTSIDE_CANCELLATION_WINDOW",
    );

    // Staff can cancel the same appointment.
    const staffCancel = await call<{ status: string }>(cancelRoute, {
      bearer: adminToken,
      params: { orgId, appointmentId: appt.id },
      body: { reason: "clinic closed" },
    });
    expect(staffCancel.status).toBe(200);
    expect(staffCancel.body.status).toBe("CANCELLED");
  });
});
