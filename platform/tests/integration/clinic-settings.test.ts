import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import {
  createDoctorWithLogin,
  createOrg,
  firstSlot,
  publishOrgForDiscovery,
  registerAndLogin,
  setWeeklyAvailability,
} from "../helpers/factories.js";
import { GET as settingsRoute, PATCH as patchSettingsRoute } from "../../app/api/orgs/[orgId]/settings/route.js";
import { POST as bookRoute } from "../../app/api/orgs/[orgId]/appointments/route.js";
import { POST as cancelRoute } from "../../app/api/orgs/[orgId]/appointments/[appointmentId]/cancel/route.js";
import { POST as selfBookRoute } from "../../app/api/patient/appointments/route.js";

let adminToken: string;
let adminUserId: string;
let orgId: string;
let doctorId: string;
let patientId: string;
let otherAdminToken: string;
let otherOrgId: string;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("csadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "csclinic")).id;
  const doc = await createDoctorWithLogin(adminToken, orgId);
  doctorId = doc.doctorId;
  await setWeeklyAvailability(adminToken, orgId, doctorId);
  await publishOrgForDiscovery(adminToken, orgId);
  patientId = (
    await db.patient.create({
      data: { organizationId: orgId, firstName: "Set", lastName: "Tings", createdById: adminUserId },
      select: { id: true },
    })
  ).id;

  const other = await registerAndLogin("csother");
  otherAdminToken = other.accessToken;
  otherOrgId = (await createOrg(other.accessToken, "csother")).id;
});
afterAll(disconnect);

async function currentSettings() {
  return db.clinicSettings.findUniqueOrThrow({ where: { organizationId: orgId } });
}

type ErrBody = { error?: { code?: string; message?: string } };

describe("clinic settings (booking rules)", () => {
  it("a new clinic exposes the schema defaults, admin-readable", async () => {
    const res = await call<{ allowPatientSelfBooking: boolean; bookingLeadTimeMinutes: number }>(settingsRoute, {
      bearer: adminToken,
      params: { orgId },
    });
    expect(res.status).toBe(200);
    expect(res.body.allowPatientSelfBooking).toBe(true);
    expect(res.body.bookingLeadTimeMinutes).toBe(120);
  });

  it("admin updates the rules; self-booking off refuses patients but not staff, and the change is audited", async () => {
    const res = await call<{ bookingLeadTimeMinutes: number; allowPatientSelfBooking: boolean }>(
      patchSettingsRoute,
      {
        method: "PATCH",
        bearer: adminToken,
        params: { orgId },
        body: {
          allowPatientSelfBooking: false,
          bookingLeadTimeMinutes: 2880, // 2 days
          cancellationWindowHours: 12,
          maxAdvanceBookingDays: 30,
          defaultAppointmentDurationMin: 20,
        },
      },
    );
    expect(res.status).toBe(200);
    expect(res.body.allowPatientSelfBooking).toBe(false);
    expect(res.body.bookingLeadTimeMinutes).toBe(2880);
    expect((await currentSettings()).defaultAppointmentDurationMin).toBe(20);

    // A patient trying to self-book is refused by the new switch…
    const pat = await registerAndLogin("cspat");
    const slot = await firstSlot(adminToken, orgId, doctorId, 5);
    const selfBook = await call<ErrBody>(selfBookRoute, {
      bearer: pat.accessToken,
      body: {
        organizationId: orgId,
        doctorId,
        scheduledStart: slot.start,
        patient: { firstName: "Pat", lastName: "Ient" },
      },
    });
    expect(selfBook.status).toBe(403);
    expect(selfBook.body.error?.code).toBe("FORBIDDEN");

    // …while staff book normally…
    const farSlot = await firstSlot(adminToken, orgId, doctorId, 5, slot.start);
    const staffBook = await call<{ id: string }>(bookRoute, {
      bearer: adminToken,
      params: { orgId },
      body: { patientId, doctorId, scheduledStart: farSlot.start },
    });
    expect(staffBook.status).toBe(201);

    // …and the new lead time applies to staff bookings too. The slots API now
    // hides everything inside the 2-day lead time, so build the too-soon start
    // by shifting a valid slot back 4 days (same weekday time; the lead-time
    // policy check fires before the availability check, so no slot math needed).
    const tooSoonStart = new Date(new Date(farSlot.start).getTime() - 4 * 86_400_000).toISOString();
    const soon = await call<ErrBody>(bookRoute, {
      bearer: adminToken,
      params: { orgId },
      body: { patientId, doctorId, scheduledStart: tooSoonStart },
    });
    expect(soon.status).toBe(409);
    expect(soon.body.error?.message).toMatch(/too soon/);

    const audit = await db.auditLog.findFirstOrThrow({
      where: { action: "CLINIC_SETTINGS_UPDATED", entityType: "ClinicSettings" },
      orderBy: { at: "desc" },
    });
    const before = audit.before as { defaultAppointmentDurationMin?: number };
    const after = audit.after as { defaultAppointmentDurationMin?: number };
    expect(before.defaultAppointmentDurationMin).toBe(15);
    expect(after.defaultAppointmentDurationMin).toBe(20);
  });

  it("out-of-bounds or unknown fields are rejected with 422 and nothing is written", async () => {
    for (const body of [
      { bookingLeadTimeMinutes: -5 },
      { maxAdvanceBookingDays: 0 },
      { defaultAppointmentDurationMin: 1 },
      { cancellationWindowHours: 337 },
      { nonsense: true },
    ]) {
      const res = await call<ErrBody>(patchSettingsRoute, {
        method: "PATCH",
        bearer: adminToken,
        params: { orgId },
        body,
      });
      expect(res.status, JSON.stringify(body)).toBe(422);
      expect(res.body.error?.code).toBe("VALIDATION_FAILED");
    }
    expect((await currentSettings()).defaultAppointmentDurationMin).toBe(20);
  });

  it("the cancellation window may not exceed the advance horizon (patients could never cancel in time)", async () => {
    const bad = await call<ErrBody>(patchSettingsRoute, {
      method: "PATCH",
      bearer: adminToken,
      params: { orgId },
      body: { cancellationWindowHours: 336, maxAdvanceBookingDays: 13 },
    });
    expect(bad.status).toBe(422);
    expect(bad.body.error?.message).toMatch(/cancellation window/i);

    // Boundary is legal: 14 days = 336 hours exactly.
    const ok = await call(patchSettingsRoute, {
      method: "PATCH",
      bearer: adminToken,
      params: { orgId },
      body: { cancellationWindowHours: 336, maxAdvanceBookingDays: 14 },
    });
    expect(ok.status).toBe(200);
  });

  // Slow by nature: two argon2-backed registrations + two full self-book flows.
  it("cancellation window gates patient self-cancel (403 inside, ok outside) but never staff", { timeout: 120_000 }, async () => {
    const reenable = await call(patchSettingsRoute, {
      method: "PATCH",
      bearer: adminToken,
      params: { orgId },
      body: { allowPatientSelfBooking: true, cancellationWindowHours: 4 },
    });
    expect(reenable.status).toBe(200);

    const pat = await registerAndLogin("cscancel");
    const slot = await firstSlot(adminToken, orgId, doctorId, 5);
    const selfBook = await call<{ id: string }>(selfBookRoute, {
      bearer: pat.accessToken,
      body: {
        organizationId: orgId,
        doctorId,
        scheduledStart: slot.start,
        patient: { firstName: "Can", lastName: "Cel" },
      },
    });
    expect(selfBook.status).toBe(201);
    const apptId = selfBook.body.id;

    // Inside the 4-hour window → refused with the dedicated code.
    const start = new Date(Date.now() + 3600_000);
    await db.appointment.update({
      where: { id: apptId },
      data: { scheduledStart: start, scheduledEnd: new Date(start.getTime() + 15 * 60_000) },
    });
    const insideWindow = await call<ErrBody>(cancelRoute, {
      bearer: pat.accessToken,
      params: { orgId, appointmentId: apptId },
      body: { reason: "running late" },
    });
    expect(insideWindow.status).toBe(403);
    expect(insideWindow.body.error?.code).toBe("OUTSIDE_CANCELLATION_WINDOW");

    // Staff are never window-limited.
    const staffCancel = await call<{ status: string }>(cancelRoute, {
      bearer: adminToken,
      params: { orgId, appointmentId: apptId },
      body: { reason: "front desk" },
    });
    expect(staffCancel.status).toBe(200);
    expect(staffCancel.body.status).toBe("CANCELLED");

    // Outside the window the patient cancels fine.
    const slot2 = await firstSlot(adminToken, orgId, doctorId, 6);
    const selfBook2 = await call<{ id: string }>(selfBookRoute, {
      bearer: pat.accessToken,
      body: {
        organizationId: orgId,
        doctorId,
        scheduledStart: slot2.start,
        patient: { firstName: "Can", lastName: "Cel" },
      },
    });
    expect(selfBook2.status).toBe(201);
    const selfCancel = await call<{ status: string }>(cancelRoute, {
      bearer: pat.accessToken,
      params: { orgId, appointmentId: selfBook2.body.id },
      body: { reason: "plans changed" },
    });
    expect(selfCancel.status).toBe(200);
    expect(selfCancel.body.status).toBe("CANCELLED");
  });

  it("non-admins and other clinics cannot read or write settings", async () => {
    const rec = await registerAndLogin("csrec");
    await db.membership.create({
      data: { userId: rec.userId, organizationId: orgId, role: "RECEPTIONIST", status: "ACTIVE" },
    });
    const recGet = await call<ErrBody>(settingsRoute, { bearer: rec.accessToken, params: { orgId } });
    expect(recGet.status).toBe(403);
    const recPatch = await call<ErrBody>(patchSettingsRoute, {
      method: "PATCH",
      bearer: rec.accessToken,
      params: { orgId },
      body: { bookingLeadTimeMinutes: 0 },
    });
    expect(recPatch.status).toBe(403);

    // An admin of a DIFFERENT clinic has no membership here → not found.
    const foreignGet = await call<ErrBody>(settingsRoute, { bearer: otherAdminToken, params: { orgId } });
    expect(foreignGet.status).toBe(404);
    const foreignPatch = await call<ErrBody>(patchSettingsRoute, {
      method: "PATCH",
      bearer: otherAdminToken,
      params: { orgId },
      body: { bookingLeadTimeMinutes: 0 },
    });
    expect(foreignPatch.status).toBe(404);

    // Sanity: the other admin manages their own clinic's settings fine.
    const own = await call<{ bookingLeadTimeMinutes: number }>(patchSettingsRoute, {
      method: "PATCH",
      bearer: otherAdminToken,
      params: { orgId: otherOrgId },
      body: { bookingLeadTimeMinutes: 60 },
    });
    expect(own.status).toBe(200);
    expect(own.body.bookingLeadTimeMinutes).toBe(60);
  });
});
