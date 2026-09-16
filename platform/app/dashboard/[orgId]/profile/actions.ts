"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { updateOrgSchema } from "@/modules/clinics/schema.js";
import {
  publishOrganization,
  requestVerification,
  unpublishOrganization,
  updateOrganization,
} from "@/modules/clinics/service.js";

function textOrNull(formData: FormData, key: string): string | null {
  const value = String(formData.get(key) ?? "").trim();
  return value.length ? value : null;
}

export async function saveProfileAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const orgType = String(formData.get("orgType") ?? "");

  const parsed = updateOrgSchema.safeParse({
    orgType: orgType.length ? orgType : null,
    tagline: textOrNull(formData, "tagline"),
    about: textOrNull(formData, "about"),
    logoUrl: textOrNull(formData, "logoUrl"),
    coverImageUrl: textOrNull(formData, "coverImageUrl"),
    publicPhone: textOrNull(formData, "publicPhone"),
    publicEmail: textOrNull(formData, "publicEmail"),
    website: textOrNull(formData, "website"),
  });

  if (!parsed.success) {
    redirect(
      `/dashboard/${orgId}/profile?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid input.")}`,
    );
  }

  try {
    await updateOrganization(ctx, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not save the profile.";
    redirect(`/dashboard/${orgId}/profile?error=${encodeURIComponent(message)}`);
  }

  revalidatePath(`/dashboard/${orgId}/profile`);
  redirect(`/dashboard/${orgId}/profile?saved=1`);
}

export async function publishAction(orgId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await publishOrganization(ctx);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not publish the profile.";
    redirect(`/dashboard/${orgId}/profile?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/profile`);
  redirect(`/dashboard/${orgId}/profile?saved=1`);
}

export async function unpublishAction(orgId: string) {
  const ctx = await requireOrgContext(orgId);
  await unpublishOrganization(ctx);
  revalidatePath(`/dashboard/${orgId}/profile`);
  redirect(`/dashboard/${orgId}/profile?saved=1`);
}

export async function requestVerificationAction(orgId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await requestVerification(ctx);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not request verification.";
    redirect(`/dashboard/${orgId}/profile?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/profile`);
  redirect(`/dashboard/${orgId}/profile?saved=1`);
}
