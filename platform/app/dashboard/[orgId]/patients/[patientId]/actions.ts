"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { createAccessGrantSchema } from "@/modules/family/schema.js";
import { createAccessGrant, revokeAccessGrant } from "@/modules/family/service.js";

function base(orgId: string, patientId: string) {
  return `/dashboard/${orgId}/patients/${patientId}`;
}
function fail(orgId: string, patientId: string, message: string): never {
  redirect(`${base(orgId, patientId)}?error=${encodeURIComponent(message)}`);
}

export async function createAccessGrantAction(orgId: string, patientId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const expiresAt = String(formData.get("expiresAt") ?? "");
  const parsed = createAccessGrantSchema.safeParse({
    granteeEmail: String(formData.get("granteeEmail") ?? ""),
    permissions: formData.getAll("permissions").map(String),
    relation: String(formData.get("relation") ?? "") || undefined,
    expiresAt: expiresAt ? new Date(expiresAt).toISOString() : undefined,
  });
  if (!parsed.success) {
    fail(orgId, patientId, parsed.error.issues[0]?.message ?? "Invalid input.");
  }
  try {
    await createAccessGrant(ctx, patientId, parsed.data);
  } catch (err) {
    fail(orgId, patientId, err instanceof AppError ? err.message : "Could not grant access.");
  }
  revalidatePath(base(orgId, patientId));
}

export async function revokeAccessGrantAction(orgId: string, patientId: string, grantId: string) {
  const ctx = await requireOrgContext(orgId);
  await revokeAccessGrant(ctx, patientId, grantId);
  revalidatePath(base(orgId, patientId));
}
