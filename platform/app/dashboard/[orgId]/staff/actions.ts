"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { createStaffSchema } from "@/modules/doctors/schema.js";
import { createStaff } from "@/modules/staff/service.js";

export async function createStaffAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = createStaffSchema.safeParse({
    email: String(formData.get("email") ?? ""),
    fullName: String(formData.get("fullName") ?? ""),
    jobTitle: String(formData.get("jobTitle") ?? "") || undefined,
  });
  if (!parsed.success) {
    redirect(`/dashboard/${orgId}/staff?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid input.")}`);
  }
  try {
    await createStaff(ctx, parsed.data);
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not add staff.";
    redirect(`/dashboard/${orgId}/staff?error=${encodeURIComponent(message)}`);
  }
  revalidatePath(`/dashboard/${orgId}/staff`);
}
