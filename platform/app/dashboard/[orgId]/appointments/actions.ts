"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { db } from "@/lib/db.js";
import { bookSchema, cancelSchema } from "@/modules/appointments/schema.js";
import {
  bookAppointment,
  cancelAppointment,
  checkInAppointment,
  completeConsultation,
  confirmAppointment,
  noShowAppointment,
  startConsultation,
} from "@/modules/appointments/service.js";

function fail(orgId: string, message: string): never {
  redirect(`/dashboard/${orgId}/appointments?error=${encodeURIComponent(message)}`);
}
function ok(orgId: string) {
  revalidatePath(`/dashboard/${orgId}/appointments`);
  revalidatePath(`/dashboard/${orgId}/queue`);
}

export async function bookAppointmentAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);

  let patientId = String(formData.get("patientId") ?? "");
  if (ctx.org!.role === "PATIENT") {
    const own = await db.patient.findFirst({
      where: { organizationId: orgId, ownerUserId: ctx.userId },
      select: { id: true },
    });
    if (!own) fail(orgId, "Ask reception to register your patient record first.");
    patientId = own.id;
  }

  const parsed = bookSchema.safeParse({
    patientId,
    doctorId: String(formData.get("doctorId") ?? ""),
    scheduledStart: String(formData.get("scheduledStart") ?? ""),
    reason: String(formData.get("reason") ?? "") || undefined,
  });
  if (!parsed.success) fail(orgId, parsed.error.issues[0]?.message ?? "Pick a doctor, date and time.");
  try {
    await bookAppointment(ctx, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not book the appointment.");
  }
  ok(orgId);
}

export async function confirmAppointmentAction(orgId: string, appointmentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await confirmAppointment(ctx, appointmentId);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not confirm.");
  }
  ok(orgId);
}

export async function cancelAppointmentAction(orgId: string, appointmentId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = cancelSchema.safeParse({ reason: String(formData.get("reason") ?? "Cancelled") });
  if (!parsed.success) fail(orgId, "A reason is required to cancel.");
  try {
    await cancelAppointment(ctx, appointmentId, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not cancel.");
  }
  ok(orgId);
}

export async function checkInAppointmentAction(orgId: string, appointmentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await checkInAppointment(ctx, appointmentId);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not check in.");
  }
  ok(orgId);
}

export async function noShowAppointmentAction(orgId: string, appointmentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await noShowAppointment(ctx, appointmentId);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not mark as no-show.");
  }
  ok(orgId);
}

export async function startAppointmentAction(orgId: string, appointmentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await startConsultation(ctx, appointmentId);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not start.");
  }
  ok(orgId);
}

export async function completeAppointmentAction(orgId: string, appointmentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await completeConsultation(ctx, appointmentId);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not complete.");
  }
  ok(orgId);
}
