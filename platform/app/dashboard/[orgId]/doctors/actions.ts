"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { createDoctorSchema } from "@/modules/doctors/schema.js";
import { createDoctor } from "@/modules/doctors/service.js";

export async function createDoctorAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = createDoctorSchema.safeParse({
    email: String(formData.get("email") ?? ""),
    fullName: String(formData.get("fullName") ?? ""),
    displayName: String(formData.get("displayName") ?? ""),
    specialty: String(formData.get("specialty") ?? "") || undefined,
    consultationDurationMin: Number(formData.get("consultationDurationMin") ?? 15),
  });
  if (!parsed.success) {
    redirect(
      `/dashboard/${orgId}/doctors?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid input.")}`,
    );
  }
  try {
    await createDoctor(ctx, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not add the doctor.";
    redirect(`/dashboard/${orgId}/doctors?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/doctors`);
}
