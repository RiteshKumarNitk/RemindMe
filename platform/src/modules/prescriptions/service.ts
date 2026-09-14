import type { z } from "zod";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { hasCapability } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import type { addItemSchema } from "./schema.js";

/** Same write rule as consultations: assigned doctor, or admin with CLINICAL_RECORD_WRITE. */
async function assertWriteAccess(ctx: RequestContext, appointmentId: string) {
  const t = tenantDb(ctx);
  const appt = await t.appointment.findFirstOrThrow({
    where: { id: appointmentId, organizationId: ctx.org!.id },
    select: { id: true, patientId: true, doctorId: true, doctor: { select: { userId: true } } },
  });
  const role = ctx.org!.role;
  const ok =
    (role === "DOCTOR" && appt.doctor.userId === ctx.userId) ||
    (role === "CLINIC_ADMIN" && hasCapability(ctx, "CLINICAL_RECORD_WRITE"));
  if (!ok) throw new AppError("FORBIDDEN", "You cannot prescribe for this appointment.");
  return appt;
}

/**
 * Adds one drug to "the" prescription for this appointment's consultation,
 * creating the Consultation and Prescription rows on first use so a doctor
 * can prescribe without a separate "start a prescription" step.
 */
export async function addPrescriptionItem(
  ctx: RequestContext,
  appointmentId: string,
  input: z.infer<typeof addItemSchema>,
) {
  const appt = await assertWriteAccess(ctx, appointmentId);
  const t = tenantDb(ctx);

  const consultation =
    (await t.consultation.findFirst({ where: { appointmentId } })) ??
    (await t.consultation.create({
      data: {
        organizationId: ctx.org!.id,
        appointmentId,
        patientId: appt.patientId,
        doctorId: appt.doctorId,
      },
    }));
  if (consultation.signedAt) {
    throw new AppError("CONFLICT", "This consultation is signed and can no longer be edited.");
  }

  let prescription = await t.prescription.findFirst({ where: { consultationId: consultation.id } });
  if (!prescription) {
    prescription = await t.prescription.create({
      data: {
        organizationId: ctx.org!.id,
        consultationId: consultation.id,
        patientId: appt.patientId,
        doctorId: appt.doctorId,
      },
    });
    await writeAudit(ctx, {
      action: "PRESCRIPTION_CREATED",
      entityType: "Prescription",
      entityId: prescription.id,
    });
  }

  const item = await t.prescriptionItem.create({
    data: {
      prescriptionId: prescription.id,
      drugName: input.drugName.trim(),
      strength: input.strength ?? null,
      form: input.form ?? null,
      dosage: input.dosage ?? null,
      frequency: input.frequency ?? null,
      durationDays: input.durationDays ?? null,
      foodInstruction: input.foodInstruction,
      instructions: input.instructions ?? null,
    },
  });
  await writeAudit(ctx, {
    action: "PRESCRIPTION_ITEM_ADDED",
    entityType: "PrescriptionItem",
    entityId: item.id,
    after: { drugName: item.drugName },
  });
  return item;
}

export async function removePrescriptionItem(
  ctx: RequestContext,
  appointmentId: string,
  itemId: string,
) {
  await assertWriteAccess(ctx, appointmentId);
  const t = tenantDb(ctx);
  const item = await t.prescriptionItem.findFirst({
    where: { id: itemId, prescription: { patient: { organizationId: ctx.org!.id } } },
  });
  if (!item) throw new AppError("NOT_FOUND", "Not found.");
  await t.prescriptionItem.delete({ where: { id: itemId } });
  await writeAudit(ctx, {
    action: "PRESCRIPTION_ITEM_REMOVED",
    entityType: "PrescriptionItem",
    entityId: itemId,
  });
  return { deleted: true };
}
