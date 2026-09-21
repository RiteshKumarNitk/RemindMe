"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { updateDoctorSchema } from "@/modules/doctors/schema.js";
import { updateDoctor } from "@/modules/doctors/service.js";

function textOrNull(formData: FormData, key: string): string | null {
  const value = String(formData.get(key) ?? "").trim();
  return value.length ? value : null;
}

function numberOrNull(formData: FormData, key: string): number | null {
  const raw = String(formData.get(key) ?? "").trim();
  if (!raw.length) return null;
  const n = Number(raw);
  return Number.isFinite(n) ? n : null;
}

export async function saveDoctorProfileAction(orgId: string, doctorId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);

  const languagesRaw = String(formData.get("languages") ?? "");
  const languages = languagesRaw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  const feeRupees = numberOrNull(formData, "consultationFee");
  const consultationFeeMinor = feeRupees === null ? null : Math.round(feeRupees * 100);

  const parsed = updateDoctorSchema.safeParse({
    bio: textOrNull(formData, "bio"),
    photoUrl: textOrNull(formData, "photoUrl"),
    qualifications: textOrNull(formData, "qualifications"),
    yearsOfExperience: numberOrNull(formData, "yearsOfExperience"),
    languages,
    consultationFeeMinor,
    isPubliclyListed: formData.get("isPubliclyListed") === "on",
  });

  if (!parsed.success) {
    redirect(
      `/dashboard/${orgId}/doctors/${doctorId}/profile?error=${encodeURIComponent(
        parsed.error.issues[0]?.message ?? "Invalid input.",
      )}`,
    );
  }

  try {
    await updateDoctor(ctx, doctorId, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not save the profile.";
    redirect(`/dashboard/${orgId}/doctors/${doctorId}/profile?error=${encodeURIComponent(message)}`);
  }

  revalidatePath(`/dashboard/${orgId}/doctors/${doctorId}/profile`);
  redirect(`/dashboard/${orgId}/doctors/${doctorId}/profile?saved=1`);
}
