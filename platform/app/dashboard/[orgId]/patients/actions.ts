"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { createPatientSchema } from "@/modules/patients/schema.js";
import { createPatient } from "@/modules/patients/service.js";

export async function createPatientAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = createPatientSchema.safeParse({
    firstName: String(formData.get("firstName") ?? ""),
    lastName: String(formData.get("lastName") ?? ""),
    phone: String(formData.get("phone") ?? "") || undefined,
    email: String(formData.get("email") ?? "") || undefined,
    ownerEmail: String(formData.get("ownerEmail") ?? "") || undefined,
  });
  if (!parsed.success) {
    redirect(`/dashboard/${orgId}/patients?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid input.")}`);
  }
  try {
    await createPatient(ctx, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not register the patient.";
    redirect(`/dashboard/${orgId}/patients?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/patients`);
}
