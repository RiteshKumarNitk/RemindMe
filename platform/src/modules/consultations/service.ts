import type { z } from "zod";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { hasCapability } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import type { saveConsultationSchema } from "./schema.js";

/**
 * Consultation notes (spec §17). Access model (RBAC.md, corrected 2026-09-14):
 * a DOCTOR gets read/write on their OWN appointment by assignment alone — no
 * separate capability needed. CLINIC_ADMIN needs CLINICAL_RECORD_READ/WRITE
 * (never implied by the role). A PATIENT may read their own, never write.
 * RECEPTIONIST: never.
 */

async function loadAppointmentForAccess(ctx: RequestContext, appointmentId: string) {
  const t = tenantDb(ctx);
  return t.appointment.findFirstOrThrow({
    where: { id: appointmentId, organizationId: ctx.org!.id },
    select: {
      id: true,
      patientId: true,
      doctorId: true,
      doctor: { select: { userId: true } },
      patient: { select: { ownerUserId: true } },
    },
  });
}

function assertRead(ctx: RequestContext, appt: { doctor: { userId: string }; patient: { ownerUserId: string | null } }) {
  const role = ctx.org!.role;
  if (role === "DOCTOR" && (appt.doctor.userId === ctx.userId || hasCapability(ctx, "CLINICAL_RECORD_READ"))) return;
  if (role === "CLINIC_ADMIN" && hasCapability(ctx, "CLINICAL_RECORD_READ")) return;
  if (role === "PATIENT" && appt.patient.ownerUserId === ctx.userId) return;
  throw new AppError("FORBIDDEN", "You do not have access to this consultation.");
}

function assertWrite(ctx: RequestContext, appt: { doctor: { userId: string } }) {
  const role = ctx.org!.role;
  if (role === "DOCTOR" && appt.doctor.userId === ctx.userId) return;
  if (role === "CLINIC_ADMIN" && hasCapability(ctx, "CLINICAL_RECORD_WRITE")) return;
  throw new AppError("FORBIDDEN", "You cannot edit this consultation.");
}

export async function getConsultation(ctx: RequestContext, appointmentId: string) {
  const appt = await loadAppointmentForAccess(ctx, appointmentId);
  assertRead(ctx, appt);
  const t = tenantDb(ctx);
  return t.consultation.findFirst({
    where: { appointmentId, organizationId: ctx.org!.id },
    include: {
      prescriptions: { include: { items: true }, orderBy: { issuedAt: "desc" } },
    },
  });
}

export async function saveConsultation(
  ctx: RequestContext,
  appointmentId: string,
  input: z.infer<typeof saveConsultationSchema>,
) {
  const appt = await loadAppointmentForAccess(ctx, appointmentId);
  assertWrite(ctx, appt);
  const t = tenantDb(ctx);

  const existing = await t.consultation.findFirst({ where: { appointmentId } });
  if (existing?.signedAt) {
    throw new AppError("CONFLICT", "This consultation is signed and can no longer be edited.");
  }

  const data = {
    subjective: input.subjective ?? null,
    objective: input.objective ?? null,
    assessment: input.assessment ?? null,
    plan: input.plan ?? null,
    followUpDate: input.followUpDate ? new Date(`${input.followUpDate}T00:00:00Z`) : null,
    testsAdvised: input.testsAdvised ?? null,
    instructions: input.instructions ?? null,
  };

  const consultation = existing
    ? await t.consultation.update({ where: { id: existing.id }, data })
    : await t.consultation.create({
        data: {
          organizationId: ctx.org!.id,
          appointmentId,
          patientId: appt.patientId,
          doctorId: appt.doctorId,
          ...data,
        },
      });

  await writeAudit(ctx, {
    action: existing ? "CONSULTATION_UPDATED" : "CONSULTATION_CREATED",
    entityType: "Consultation",
    entityId: consultation.id,
  });
  return consultation;
}

export async function signConsultation(ctx: RequestContext, appointmentId: string) {
  const appt = await loadAppointmentForAccess(ctx, appointmentId);
  assertWrite(ctx, appt);
  const t = tenantDb(ctx);
  const existing = await t.consultation.findFirst({ where: { appointmentId } });
  if (!existing) {
    throw new AppError("VALIDATION_FAILED", "Save consultation notes before signing.");
  }
  if (existing.signedAt) return existing;
  const signed = await t.consultation.update({
    where: { id: existing.id },
    data: { signedAt: new Date() },
  });
  await writeAudit(ctx, {
    action: "CONSULTATION_SIGNED",
    entityType: "Consultation",
    entityId: signed.id,
  });
  return signed;
}
