"use server";

import { redirect } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { requireWebUser } from "@/lib/web-context.js";
import { createOrgSchema } from "@/modules/tenancy/schema.js";
import { createOrganization } from "@/modules/tenancy/service.js";

export async function createOrgAction(formData: FormData) {
  const ctx = await requireWebUser();
  const parsed = createOrgSchema.safeParse({
    name: String(formData.get("name") ?? ""),
    slug: String(formData.get("slug") ?? "")
      .trim()
      .toLowerCase(),
    timezone: String(formData.get("timezone") ?? "Asia/Kolkata"),
  });
  if (!parsed.success) {
    redirect(`/dashboard/new?error=${encodeURIComponent(parsed.error.issues[0]?.message ?? "Invalid input.")}`);
  }

  let orgId: string;
  try {
    const org = await createOrganization(ctx, parsed.data);
    orgId = org.id;
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not create the clinic.";
    redirect(`/dashboard/new?error=${encodeURIComponent(message)}`);
  }
  redirect(`/dashboard/${orgId}/profile`);
}
