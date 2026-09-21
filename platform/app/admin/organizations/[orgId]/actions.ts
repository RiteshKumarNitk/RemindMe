"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { setOrganizationActive, setOrganizationVerification } from "@/modules/superadmin/service.js";

export async function setOrganizationActiveAction(orgId: string, isActive: boolean) {
  const ctx = await requireSuperAdmin();
  try {
    await setOrganizationActive(ctx, orgId, isActive);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not update the clinic.";
    redirect(`/admin/organizations/${orgId}?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/admin/organizations/${orgId}`);
  revalidatePath(`/admin/organizations`);
}

export async function setOrganizationVerificationAction(
  orgId: string,
  status: "VERIFIED" | "REJECTED",
) {
  const ctx = await requireSuperAdmin();
  try {
    await setOrganizationVerification(ctx, orgId, { status });
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not update verification.";
    redirect(`/admin/organizations/${orgId}?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/admin/organizations/${orgId}`);
  revalidatePath(`/admin/organizations`);
  revalidatePath(`/admin/verification`);
}
