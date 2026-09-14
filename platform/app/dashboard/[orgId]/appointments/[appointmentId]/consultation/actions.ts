"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { saveConsultationSchema } from "@/modules/consultations/schema.js";
import { saveConsultation, signConsultation } from "@/modules/consultations/service.js";
import { addItemSchema } from "@/modules/prescriptions/schema.js";
import { addPrescriptionItem, removePrescriptionItem } from "@/modules/prescriptions/service.js";
import { completeConsultation, startConsultation } from "@/modules/appointments/service.js";

function base(orgId: string, appointmentId: string) {
  return `/dashboard/${orgId}/appointments/${appointmentId}/consultation`;
}
function fail(orgId: string, appointmentId: string, message: string): never {
  redirect(`${base(orgId, appointmentId)}?error=${encodeURIComponent(message)}`);
}

export async function saveConsultationAction(orgId: string, appointmentId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = saveConsultationSchema.safeParse({
    subjective: String(formData.get("subjective") ?? "") || undefined,
    objective: String(formData.get("objective") ?? "") || undefined,
    assessment: String(formData.get("assessment") ?? "") || undefined,
    plan: String(formData.get("plan") ?? "") || undefined,
    followUpDate: String(formData.get("followUpDate") ?? "") || undefined,
    testsAdvised: String(formData.get("testsAdvised") ?? "") || undefined,
    instructions: String(formData.get("instructions") ?? "") || undefined,
  });
  if (!parsed.success) fail(orgId, appointmentId, "Invalid input.");
  try {
    await saveConsultation(ctx, appointmentId, parsed.data);
  } catch (err) {
    fail(orgId, appointmentId, err instanceof AppError ? err.message : "Could not save notes.");
  }
  revalidatePath(base(orgId, appointmentId));
}

export async function addPrescriptionItemAction(orgId: string, appointmentId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = addItemSchema.safeParse({
    drugName: String(formData.get("drugName") ?? ""),
    strength: String(formData.get("strength") ?? "") || undefined,
    dosage: String(formData.get("dosage") ?? "") || undefined,
    frequency: String(formData.get("frequency") ?? "") || undefined,
    durationDays: formData.get("durationDays") || undefined,
    instructions: String(formData.get("instructions") ?? "") || undefined,
  });
  if (!parsed.success) fail(orgId, appointmentId, parsed.error.issues[0]?.message ?? "Invalid medicine.");
  try {
    await addPrescriptionItem(ctx, appointmentId, parsed.data);
  } catch (err) {
    fail(orgId, appointmentId, err instanceof AppError ? err.message : "Could not add the medicine.");
  }
  revalidatePath(base(orgId, appointmentId));
}

export async function removePrescriptionItemAction(orgId: string, appointmentId: string, itemId: string) {
  const ctx = await requireOrgContext(orgId);
  await removePrescriptionItem(ctx, appointmentId, itemId);
  revalidatePath(base(orgId, appointmentId));
}

export async function startConsultationAction(orgId: string, appointmentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await startConsultation(ctx, appointmentId);
  } catch (err) {
    fail(orgId, appointmentId, err instanceof AppError ? err.message : "Could not start.");
  }
  revalidatePath(base(orgId, appointmentId));
}

export async function signAndCompleteAction(orgId: string, appointmentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await signConsultation(ctx, appointmentId);
    await completeConsultation(ctx, appointmentId);
  } catch (err) {
    fail(orgId, appointmentId, err instanceof AppError ? err.message : "Could not sign & complete.");
  }
  revalidatePath(base(orgId, appointmentId));
  revalidatePath(`/dashboard/${orgId}/appointments`);
  redirect(`/dashboard/${orgId}/appointments`);
}
