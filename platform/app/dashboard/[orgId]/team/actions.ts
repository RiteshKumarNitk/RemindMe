"use server";

import { redirect } from "next/navigation";
import { revalidatePath } from "next/cache";
import type { MembershipCapability } from "@prisma/client";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { capabilitiesSchema, inviteMemberSchema, updateMemberSchema } from "@/modules/clinics/schema.js";
import {
  inviteMember,
  removeMember,
  setMemberCapabilities,
  updateMember,
} from "@/modules/clinics/service.js";

const ALL_CAPS: MembershipCapability[] = [
  "CLINICAL_RECORD_READ",
  "CLINICAL_RECORD_WRITE",
  "BILLING_MANAGE",
  "DATA_EXPORT",
];

function fail(orgId: string, message: string): never {
  redirect(`/dashboard/${orgId}/team?error=${encodeURIComponent(message)}`);
}

export async function inviteMemberAction(orgId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const parsed = inviteMemberSchema.safeParse({
    email: String(formData.get("email") ?? ""),
    fullName: String(formData.get("fullName") ?? ""),
    role: String(formData.get("role") ?? "RECEPTIONIST"),
  });
  if (!parsed.success) fail(orgId, parsed.error.issues[0]?.message ?? "Invalid input.");
  try {
    await inviteMember(ctx, parsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not add the member.");
  }
  revalidatePath(`/dashboard/${orgId}/team`);
}

export async function saveMemberAction(orgId: string, membershipId: string, formData: FormData) {
  const ctx = await requireOrgContext(orgId);
  const roleParsed = updateMemberSchema.safeParse({
    role: String(formData.get("role") ?? ""),
    status: String(formData.get("status") ?? "ACTIVE"),
  });
  if (!roleParsed.success) fail(orgId, roleParsed.error.issues[0]?.message ?? "Invalid input.");

  const capabilities = ALL_CAPS.filter((c) => formData.get(`cap-${c}`) === "on");
  const capsParsed = capabilitiesSchema.safeParse({ capabilities });
  if (!capsParsed.success) fail(orgId, "Invalid capabilities.");

  try {
    await updateMember(ctx, membershipId, roleParsed.data);
    await setMemberCapabilities(ctx, membershipId, capsParsed.data);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not save changes.");
  }
  revalidatePath(`/dashboard/${orgId}/team`);
}

export async function removeMemberAction(orgId: string, membershipId: string) {
  const ctx = await requireOrgContext(orgId);
  try {
    await removeMember(ctx, membershipId);
  } catch (err) {
    fail(orgId, err instanceof AppError ? err.message : "Could not remove the member.");
  }
  revalidatePath(`/dashboard/${orgId}/team`);
}
