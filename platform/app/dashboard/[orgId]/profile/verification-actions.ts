"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { deleteVerificationDocument } from "@/modules/verification-documents/service.js";

export async function deleteVerificationDocAction(orgId: string, documentId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await deleteVerificationDocument(ctx, documentId);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not delete the document.";
    redirect(`/dashboard/${orgId}/profile?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/profile`);
  redirect(`/dashboard/${orgId}/profile?saved=1`);
}
