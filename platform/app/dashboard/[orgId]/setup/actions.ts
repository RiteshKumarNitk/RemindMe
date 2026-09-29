"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import {
  publishOrganization,
  requestVerification,
  unpublishOrganization,
} from "@/modules/clinics/service.js";

function revalidateAll(orgId: string) {
  revalidatePath(`/dashboard/${orgId}/setup`);
  revalidatePath(`/dashboard/${orgId}`);
  revalidatePath(`/dashboard/${orgId}/profile`);
}

export async function publishSetupAction(orgId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await publishOrganization(ctx);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not publish.";
    redirect(`/dashboard/${orgId}/setup?error=${encodeURIComponent(message)}`);
  }
  revalidateAll(orgId);
}

export async function requestVerificationSetupAction(orgId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await requestVerification(ctx);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not request verification.";
    redirect(`/dashboard/${orgId}/setup?error=${encodeURIComponent(message)}`);
  }
  revalidateAll(orgId);
}

export async function unpublishSetupAction(orgId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await unpublishOrganization(ctx);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not unpublish.";
    redirect(`/dashboard/${orgId}/setup?error=${encodeURIComponent(message)}`);
  }
  revalidateAll(orgId);
}
