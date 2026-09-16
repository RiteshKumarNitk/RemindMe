import type { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { computeSlots } from "@/modules/availability/service.js";
import { bookAppointment } from "@/modules/appointments/service.js";
import type { RequestContext, OrgContext } from "@/lib/context.js";
import type { publicSlotsQuerySchema, selfBookAppointmentSchema, selfPatientDetailsSchema } from "./schema.js";

/**
 * Orchestrates "a logged-in stranger, found via public discovery, books
 * themselves in" (PRODUCT_EVOLUTION_PLAN.md §9/§15 Phase 6). Deliberately a
 * thin module: it does NOT reimplement slot math or booking rules — every
 * real decision (availability, lead time, double-booking, appointment
 * status) still goes through `computeSlots`/`bookAppointment` exactly as a
 * staff-initiated booking does. Its only job is the one thing that couldn't
 * exist before now: turning "an authenticated User with no relationship to
 * this clinic yet" into "a PATIENT member with a Patient record," so those
 * existing functions have something to operate on.
 */

const PUBLIC_SLOTS_ORG_CHECK = { isActive: true, isPubliclyListed: true } as const;

/**
 * Read-only: public slot availability for a doctor, reusing the exact same
 * `computeSlots` staff/patient dashboards call. `computeSlots` only ever
 * reads `ctx.org!.id` — never `ctx.userId` or role — so a synthetic,
 * unauthenticated context is safe to construct here (ADR: see DECISIONS.md
 * "public slots" entry). Never exposed for a private/unpublished org.
 */
export async function getPublicDoctorSlots(
  doctorId: string,
  q: z.infer<typeof publicSlotsQuerySchema>,
) {
  const doctor = await db.doctorProfile.findFirst({
    where: {
      id: doctorId,
      isActive: true,
      isPubliclyListed: true,
      organization: PUBLIC_SLOTS_ORG_CHECK,
    },
    select: { organizationId: true },
  });
  if (!doctor) throw new AppError("NOT_FOUND", "Not found.");

  const syntheticCtx: RequestContext = {
    userId: "",
    isPlatformAdmin: false,
    isGuest: false,
    requestId: "public-slots",
    ip: null,
    userAgent: null,
    org: { id: doctor.organizationId, membershipId: "", role: "PATIENT", capabilities: [], isActive: true },
  };
  return computeSlots(syntheticCtx, doctorId, q.date, q.appointmentTypeId);
}

/**
 * Idempotent: find-or-create this user's PATIENT membership + Patient
 * record for `organizationId`. Only ever runs against a publicly-listed,
 * active org — a caller can't use this to quietly join a private clinic
 * whose id they happened to know (ADR: see DECISIONS.md). Race-safe via two
 * real DB unique constraints (`Membership_userId_organizationId_role_key`,
 * `Patient_organizationId_ownerUserId_key`) — a concurrent double-submit
 * can't create duplicate rows, Postgres's `ON CONFLICT` upsert serializes it.
 */
async function ensurePatientMembership(
  ctx: RequestContext,
  organizationId: string,
  details: z.infer<typeof selfPatientDetailsSchema>,
): Promise<{ org: OrgContext; patientId: string }> {
  if (ctx.isGuest) {
    throw new AppError("FORBIDDEN", "Guest accounts cannot book appointments.");
  }

  // Fast path: already a patient here (the overwhelmingly common case after
  // the first visit) — skip the write entirely, no audit noise on a repeat.
  const [existingMembership, existingPatient] = await Promise.all([
    db.membership.findFirst({
      where: { userId: ctx.userId, organizationId, role: "PATIENT", status: "ACTIVE" },
      select: { id: true, capabilities: true },
    }),
    db.patient.findUnique({
      where: { organizationId_ownerUserId: { organizationId, ownerUserId: ctx.userId } },
      select: { id: true, isActive: true },
    }),
  ]);
  if (existingMembership && existingPatient?.isActive) {
    return {
      org: {
        id: organizationId,
        membershipId: existingMembership.id,
        role: "PATIENT",
        capabilities: existingMembership.capabilities,
        isActive: true,
      },
      patientId: existingPatient.id,
    };
  }

  const org = await db.organization.findFirst({
    where: { id: organizationId, ...PUBLIC_SLOTS_ORG_CHECK },
    select: { id: true },
  });
  if (!org) throw new AppError("NOT_FOUND", "Not found.");

  const user = await db.user.findUniqueOrThrow({
    where: { id: ctx.userId },
    select: { email: true },
  });

  const result = await db.$transaction(async (tx) => {
    const membership = await tx.membership.upsert({
      where: { userId_organizationId_role: { userId: ctx.userId, organizationId, role: "PATIENT" } },
      create: { userId: ctx.userId, organizationId, role: "PATIENT", status: "ACTIVE" },
      update: { status: "ACTIVE" },
      select: { id: true, capabilities: true },
    });

    const patient = await tx.patient.upsert({
      where: { organizationId_ownerUserId: { organizationId, ownerUserId: ctx.userId } },
      create: {
        organizationId,
        ownerUserId: ctx.userId,
        firstName: details.firstName.trim(),
        lastName: details.lastName.trim(),
        phone: details.phone ?? null,
        email: user.email,
        dateOfBirth: details.dateOfBirth ? new Date(`${details.dateOfBirth}T00:00:00Z`) : null,
        sex: details.sex ?? null,
        createdById: ctx.userId,
      },
      update: { isActive: true },
      select: { id: true },
    });

    return { membershipId: membership.id, capabilities: membership.capabilities, patientId: patient.id };
  });

  await writeAudit(
    {
      ...ctx,
      org: { id: organizationId, membershipId: result.membershipId, role: "PATIENT", capabilities: [], isActive: true },
    },
    {
      action: "PATIENT_SELF_REGISTERED",
      entityType: "Patient",
      entityId: result.patientId,
      after: { organizationId },
    },
  );

  return {
    org: {
      id: organizationId,
      membershipId: result.membershipId,
      role: "PATIENT",
      capabilities: result.capabilities,
      isActive: true,
    },
    patientId: result.patientId,
  };
}

export async function selfBookAppointment(
  ctx: RequestContext,
  input: z.infer<typeof selfBookAppointmentSchema>,
) {
  const { org, patientId } = await ensurePatientMembership(ctx, input.organizationId, input.patient);
  const orgCtx: RequestContext = { ...ctx, org };

  return bookAppointment(orgCtx, {
    patientId,
    doctorId: input.doctorId,
    scheduledStart: input.scheduledStart,
    appointmentTypeId: input.appointmentTypeId,
    locationId: input.locationId,
    reason: input.reason,
  });
}
