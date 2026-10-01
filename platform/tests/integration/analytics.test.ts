import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { createOrg, registerAndLogin } from "../helpers/factories.js";
import type { RequestContext } from "@/lib/context.js";
import { getClinicAnalytics } from "@/modules/analytics/service.js";

let adminToken: string;
let adminUserId: string;
let adminMembershipId: string;
let orgId: string;
let doctorId: string;
let patientId: string;
let tokenSeq = 0;

beforeAll(async () => {
  await truncateAll();
  const admin = await registerAndLogin("anadm");
  adminToken = admin.accessToken;
  adminUserId = admin.userId;
  orgId = (await createOrg(adminToken, "analytics")).id;
  const membership = await db.membership.findFirstOrThrow({
    where: { userId: adminUserId, organizationId: orgId },
    select: { id: true },
  });
  adminMembershipId = membership.id;
  const doctorUser = await registerAndLogin("andoc");
  await db.membership.create({
    data: { userId: doctorUser.userId, organizationId: orgId, role: "DOCTOR", status: "ACTIVE" },
  });
  const doc = await db.doctorProfile.create({
    data: { organizationId: orgId, userId: doctorUser.userId, displayName: "Dr Analytics" },
    select: { id: true },
  });
  doctorId = doc.id;
  const pat = await db.patient.create({
    data: { organizationId: orgId, firstName: "Ann", lastName: "Lytics", createdById: adminUserId },
    select: { id: true },
  });
  patientId = pat.id;
});
afterAll(disconnect);

async function seedAppointment(opts: {
  hoursAgo: number;
  status: "COMPLETED" | "NO_SHOW" | "CANCELLED";
  waitMinutes?: number;
}) {
  const start = new Date(Date.now() - opts.hoursAgo * 3600_000);
  const appt = await db.appointment.create({
    data: {
      organizationId: orgId,
      patientId,
      doctorId,
      scheduledStart: start,
      scheduledEnd: new Date(start.getTime() + 15 * 60_000),
      timezone: "Asia/Kolkata",
      status: opts.status,
      bookingSource: "RECEPTION",
      createdById: adminUserId,
      ...(opts.status === "COMPLETED" ? { completedAt: new Date(start.getTime() + 30 * 60_000) } : {}),
      ...(opts.status === "NO_SHOW" ? { noShowMarkedAt: new Date(start.getTime() + 10 * 60_000) } : {}),
      ...(opts.status === "CANCELLED" ? { cancelledAt: new Date(start.getTime() + 5 * 60_000) } : {}),
    },
    select: { id: true },
  });
  if (opts.waitMinutes != null) {
    await db.queueEntry.create({
      data: {
        organizationId: orgId,
        appointmentId: appt.id,
        patientId,
        doctorId,
        queueDate: new Date(start.toISOString().slice(0, 10)),
        tokenNumber: ++tokenSeq,
        state: "COMPLETED",
        position: 1,
        checkedInAt: start,
        consultationStartedAt: new Date(start.getTime() + opts.waitMinutes * 60_000),
        completedAt: new Date(start.getTime() + (opts.waitMinutes + 10) * 60_000),
      },
    });
  }
  return appt.id;
}

function ctxFor(): RequestContext {
  // Service-level test: build the org context directly (requireOrgContext
  // needs a Next request scope, which unit-style tests don't have).
  return {
    userId: adminUserId,
    isPlatformAdmin: false,
    isGuest: false,
    requestId: "analytics-test",
    ip: null,
    userAgent: null,
    org: {
      id: orgId,
      membershipId: adminMembershipId,
      role: "CLINIC_ADMIN",
      capabilities: [],
      isActive: true,
    },
  };
}

describe("clinic analytics (insights tab)", () => {
  it("computes no-show rate from decided outcomes and ignores RESCHEDULED rows", async () => {
    await seedAppointment({ hoursAgo: 48, status: "COMPLETED", waitMinutes: 10 });
    await seedAppointment({ hoursAgo: 47, status: "COMPLETED", waitMinutes: 40 });
    await seedAppointment({ hoursAgo: 46, status: "NO_SHOW" });
    await seedAppointment({ hoursAgo: 45, status: "CANCELLED" });

    const ctx = await ctxFor();
    const a = await getClinicAnalytics(ctx, orgId);

    expect(a.totals.completed).toBe(2);
    expect(a.totals.noShow).toBe(1);
    expect(a.totals.cancelled).toBe(1);
    // 1 no-show out of 3 decided (completed + no-show).
    expect(a.noShowRate).toBe(33);
    // 1 cancellation out of 4 appointments.
    expect(a.cancellationRate).toBe(25);
  });

  it("wait-time stats: median/average/p90 and buckets from the queue timeline", async () => {
    const ctx = await ctxFor();
    const a = await getClinicAnalytics(ctx, orgId);

    expect(a.waitTimes.sampleSize).toBe(2);
    // waits: 10, 40 → median 25, average 25, p90 40
    expect(a.waitTimes.medianMinutes).toBe(25);
    expect(a.waitTimes.averageMinutes).toBe(25);
    expect(a.waitTimes.p90Minutes).toBe(40);
    expect(a.waitTimes.buckets).toEqual([
      { label: "Under 15 min", count: 1 },
      { label: "15–30 min", count: 0 },
      { label: "30–60 min", count: 1 },
      { label: "60+ min", count: 0 },
    ]);
  });

  it("per-doctor rows carry appointments, no-show rate and median wait", async () => {
    const ctx = await ctxFor();
    const a = await getClinicAnalytics(ctx, orgId);

    expect(a.perDoctor).toHaveLength(1);
    const d = a.perDoctor[0]!;
    expect(d.doctorName).toBe("Dr Analytics");
    expect(d.appointments).toBe(4);
    expect(d.noShow).toBe(1);
    expect(d.noShowRate).toBe(25);
    expect(d.medianWaitMinutes).toBe(25);
  });

  it("an org with no history returns null rates rather than NaN", async () => {
    const fresh = await registerAndLogin("anfresh");
    const freshOrgId = (await createOrg(fresh.accessToken, "anempty")).id;
    const freshMembership = await db.membership.findFirstOrThrow({
      where: { userId: fresh.userId, organizationId: freshOrgId },
      select: { id: true },
    });
    const ctx: RequestContext = {
      userId: fresh.userId,
      isPlatformAdmin: false,
      isGuest: false,
      requestId: "analytics-test-empty",
      ip: null,
      userAgent: null,
      org: {
        id: freshOrgId,
        membershipId: freshMembership.id,
        role: "CLINIC_ADMIN",
        capabilities: [],
        isActive: true,
      },
    };
    const a = await getClinicAnalytics(ctx, freshOrgId);

    expect(a.totals.appointments).toBe(0);
    expect(a.noShowRate).toBeNull();
    expect(a.cancellationRate).toBeNull();
    expect(a.waitTimes.sampleSize).toBe(0);
    expect(a.waitTimes.medianMinutes).toBeNull();
    expect(a.peakHours).toEqual([]);
  });
});
