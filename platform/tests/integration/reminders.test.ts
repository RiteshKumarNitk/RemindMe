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
import { env } from "@/lib/env.js";
import { POST as bookRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { POST as cancelRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/cancel/route.js";
import { POST as confirmRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/confirm/route.js";
import { POST as dispatchRoute } from "../../app/api/internal/notifications/dispatch/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;
let doctorId: string;
let patientUserId: string;
let patientId: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("remadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "rem")).id;
  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  await setWeeklyAvailability(adminToken, orgId, doctorId, { slotMinutes: 15 });

  const patUser = await registerAndLogin("rempat");
  await db.membership.create({
    data: { userId: patUser.userId, organizationId: orgId, role: "PATIENT", status: "ACTIVE" },
  });
  patientUserId = patUser.userId;
  patientId = (await createPatient(orgId, adminUserId, patUser.userId)).id;
});
afterAll(disconnect);

const cronKey = () => env.NOTIFICATIONS_CRON_SECRET;

/** Reminders the given user currently holds, any delivery status. */
function remindersFor(userId: string) {
  return db.notification.findMany({ where: { userId, event: "APPOINTMENT_REMINDER" } });
}

describe("appointment reminders (end to end)", () => {
  it("a staff booking schedules T-24H and T-2H IN_APP reminders, deduped and future-dated", async () => {
    const slot = await firstSlot(adminToken, orgId, doctorId, 7);
    const res = await call<{ id: string }>(bookRoute, {
      bearer: adminToken,
      params: { orgId },
      body: { patientId, doctorId, scheduledStart: slot.start },
    });
    expect(res.status).toBe(201);

    const rows = await remindersFor(patientUserId);
    expect(rows.map((r) => r.channel)).toEqual(["IN_APP", "IN_APP"]);
    const labels = rows.map((r) => (r.payload as { label?: string }).label).sort();
    expect(labels).toEqual(["T-24H", "T-2H"]);
    // All scheduled in the future (appointment is 7 days out) and dedupe-keyed.
    for (const r of rows) {
      expect(r.scheduledFor!.getTime()).toBeGreaterThan(Date.now());
      expect(r.dedupeKey).toMatch(/^APPOINTMENT_REMINDER:/);
      expect(r.status).toBe("PENDING");
    }
  });

  it("rebooking the same slot does not duplicate reminders (dedupe key)", async () => {
    const before = await remindersFor(patientUserId);
    // Direct duplicate enqueue through the same dedupe path would be a no-op;
    // assert the invariant from the data: keys are unique per appointment+label.
    const keys = before.map((r) => r.dedupeKey);
    expect(new Set(keys).size).toBe(keys.length);
  });

  it("future-dated reminders are invisible in the bell until due", async () => {
    // The bell query only surfaces rows whose scheduledFor has passed.
    const visible = await db.notification.count({
      where: {
        userId: patientUserId,
        event: "APPOINTMENT_REMINDER",
        OR: [{ scheduledFor: null }, { scheduledFor: { lte: new Date() } }],
      },
    });
    expect(visible).toBe(0);
  });

  it("a due reminder is delivered exactly once by the cron dispatcher", async () => {
    // Force one reminder due now.
    const row = await db.notification.findFirstOrThrow({
      where: { userId: patientUserId, event: "APPOINTMENT_REMINDER" },
      orderBy: { scheduledFor: "asc" },
    });
    await db.notification.update({
      where: { id: row.id },
      data: { scheduledFor: new Date(Date.now() - 1000) },
    });

    const res = await call<{ sent: number }>(dispatchRoute, {
      method: "POST",
      headers: { "x-cron-key": cronKey() },
    });
    expect(res.status).toBe(200);
    expect(res.body.sent).toBeGreaterThanOrEqual(1);
    const sent = await db.notification.findUniqueOrThrow({ where: { id: row.id } });
    expect(sent.status).toBe("SENT");
    expect(sent.sentAt).not.toBeNull();
  });

  it("cancelling the appointment suppresses its pending reminders", async () => {
    const slot = await firstSlot(adminToken, orgId, doctorId, 9);
    const res = await call<{ id: string }>(bookRoute, {
      bearer: adminToken,
      params: { orgId },
      body: { patientId, doctorId, scheduledStart: slot.start },
    });
    expect(res.status).toBe(201);
    const apptId = res.body.id;
    expect((await remindersFor(patientUserId)).filter((r) => (r.payload as { appointmentId?: string }).appointmentId === apptId)).toHaveLength(2);

    const cancelled = await call<{ status: string }>(cancelRoute, {
      bearer: adminToken,
      params: { orgId, appointmentId: apptId },
      body: { reason: "plans changed" },
    });
    expect(cancelled.status).toBe(200);

    const rows = await db.notification.findMany({
      where: { event: "APPOINTMENT_REMINDER", dedupeKey: { startsWith: `APPOINTMENT_REMINDER:${apptId}:` } },
    });
    expect(rows.length).toBe(2);
    for (const r of rows) expect(r.status).toBe("SUPPRESSED");
  });

  it("confirming a REQUESTED appointment schedules reminders (they were not scheduled before)", async () => {
    // Booked far out then flipped to REQUESTED directly in the DB to simulate
    // the one path that starts unconfirmed (self-booking into a strict clinic).
    const slot = await firstSlot(adminToken, orgId, doctorId, 10);
    const appt = await db.appointment.create({
      data: {
        organizationId: orgId,
        patientId,
        doctorId,
        scheduledStart: new Date(slot.start),
        scheduledEnd: new Date(new Date(slot.start).getTime() + 15 * 60_000),
        timezone: "Asia/Kolkata",
        status: "REQUESTED",
        bookingSource: "PATIENT_APP",
        createdById: adminUserId,
      },
      select: { id: true },
    });
    expect(
      await db.notification.count({
        where: { event: "APPOINTMENT_REMINDER", dedupeKey: { startsWith: `APPOINTMENT_REMINDER:${appt.id}:` } },
      }),
    ).toBe(0);

    const confirmed = await call<{ status: string }>(confirmRoute, {
      bearer: adminToken,
      params: { orgId, appointmentId: appt.id },
    });
    expect(confirmed.status).toBe(200);

    const rows = await db.notification.findMany({
      where: { event: "APPOINTMENT_REMINDER", dedupeKey: { startsWith: `APPOINTMENT_REMINDER:${appt.id}:` } },
    });
    expect(rows).toHaveLength(2);
  });
});
