import { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { assertRole, assertCanEditCapabilities } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import type {
  capabilitiesSchema,
  createLocationSchema,
  inviteMemberSchema,
  updateMemberSchema,
  updateOrgSchema,
  updateSettingsSchema,
} from "./schema.js";

export async function getOrganization(ctx: RequestContext) {
  const t = tenantDb(ctx);
  const org = await t.organization.findFirstOrThrow({
    where: { id: ctx.org!.id },
    select: {
      id: true,
      name: true,
      slug: true,
      timezone: true,
      isActive: true,
      createdAt: true,
      settings: true,
      locations: { where: { isActive: true }, orderBy: { name: "asc" } },
    },
  });
  return org;
}

export async function updateOrganization(
  ctx: RequestContext,
  input: z.infer<typeof updateOrgSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const before = await t.organization.findFirstOrThrow({
    where: { id: ctx.org!.id },
    select: { name: true, timezone: true },
  });
  const org = await t.organization.update({
    where: { id: ctx.org!.id },
    data: {
      ...(input.name !== undefined ? { name: input.name.trim() } : {}),
      ...(input.timezone !== undefined ? { timezone: input.timezone } : {}),
    },
    select: { id: true, name: true, slug: true, timezone: true, isActive: true },
  });
  await writeAudit(ctx, {
    action: "ORGANIZATION_UPDATED",
    entityType: "Organization",
    entityId: org.id,
    before,
    after: { name: org.name, timezone: org.timezone },
  });
  return org;
}

export async function getSettings(ctx: RequestContext) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  return t.clinicSettings.findFirstOrThrow({ where: { organizationId: ctx.org!.id } });
}

export async function updateSettings(
  ctx: RequestContext,
  input: z.infer<typeof updateSettingsSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const before = await t.clinicSettings.findFirstOrThrow({
    where: { organizationId: ctx.org!.id },
  });
  const updated = await t.clinicSettings.update({
    where: { organizationId: ctx.org!.id },
    data: input,
  });
  await writeAudit(ctx, {
    action: "CLINIC_SETTINGS_UPDATED",
    entityType: "ClinicSettings",
    entityId: updated.id,
    before,
    after: updated,
  });
  return updated;
}

export async function listLocations(ctx: RequestContext) {
  const t = tenantDb(ctx);
  return t.clinicLocation.findMany({
    where: { organizationId: ctx.org!.id },
    orderBy: { name: "asc" },
  });
}

export async function createLocation(
  ctx: RequestContext,
  input: z.infer<typeof createLocationSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const loc = await t.clinicLocation.create({
    data: { ...input, organizationId: ctx.org!.id },
  });
  await writeAudit(ctx, {
    action: "LOCATION_CREATED",
    entityType: "ClinicLocation",
    entityId: loc.id,
    after: loc,
  });
  return loc;
}

export async function listMembers(ctx: RequestContext) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const members = await t.membership.findMany({
    where: { organizationId: ctx.org!.id },
    select: {
      id: true,
      role: true,
      status: true,
      capabilities: true,
      createdAt: true,
      user: { select: { id: true, email: true, fullName: true } },
    },
    orderBy: { createdAt: "asc" },
  });
  return members;
}

/**
 * Invite (MVP: create-or-attach directly; the token-based flow is Phase 3).
 * Creates the user if new (no password — they set one via reset), then a
 * membership. Cannot mint a SUPER_ADMIN or a second identical role.
 */
export async function inviteMember(
  ctx: RequestContext,
  input: z.infer<typeof inviteMemberSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const email = input.email.trim().toLowerCase();

  const membership = await db.$transaction(async (tx) => {
    const user =
      (await tx.user.findUnique({ where: { email }, select: { id: true } })) ??
      (await tx.user.create({
        data: { email, fullName: input.fullName.trim() },
        select: { id: true },
      }));

    const existing = await tx.membership.findFirst({
      where: { userId: user.id, organizationId: ctx.org!.id, role: input.role },
      select: { id: true },
    });
    if (existing) {
      throw new AppError("CONFLICT", "That person already holds this role here.");
    }

    return tx.membership.create({
      data: {
        userId: user.id,
        organizationId: ctx.org!.id,
        role: input.role,
        status: "ACTIVE",
        invitedById: ctx.userId,
      },
      select: {
        id: true,
        role: true,
        status: true,
        capabilities: true,
        user: { select: { id: true, email: true, fullName: true } },
      },
    });
  });

  await writeAudit(ctx, {
    action: "MEMBER_ADDED",
    entityType: "Membership",
    entityId: membership.id,
    after: { role: membership.role, email: membership.user.email },
  });
  return membership;
}

export async function updateMember(
  ctx: RequestContext,
  membershipId: string,
  input: z.infer<typeof updateMemberSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const current = await t.membership.findFirstOrThrow({
    where: { id: membershipId, organizationId: ctx.org!.id },
    select: { id: true, role: true, status: true, userId: true },
  });
  if (current.userId === ctx.userId && input.role && input.role !== current.role) {
    throw new AppError("FORBIDDEN", "You cannot change your own role.");
  }
  const updated = await t.membership.update({
    where: { id: membershipId },
    data: {
      ...(input.role ? { role: input.role } : {}),
      ...(input.status ? { status: input.status } : {}),
    },
    select: { id: true, role: true, status: true, capabilities: true },
  });
  await writeAudit(ctx, {
    action: "MEMBER_ROLE_CHANGED",
    entityType: "Membership",
    entityId: membershipId,
    before: { role: current.role, status: current.status },
    after: { role: updated.role, status: updated.status },
  });
  return updated;
}

export async function removeMember(ctx: RequestContext, membershipId: string) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const target = await t.membership.findFirstOrThrow({
    where: { id: membershipId, organizationId: ctx.org!.id },
    select: { id: true, userId: true, role: true },
  });
  if (target.userId === ctx.userId) {
    throw new AppError("FORBIDDEN", "You cannot remove your own membership.");
  }
  await t.membership.delete({ where: { id: membershipId } });
  await writeAudit(ctx, {
    action: "MEMBER_REMOVED",
    entityType: "Membership",
    entityId: membershipId,
    before: { role: target.role },
  });
  return { removed: true };
}

/**
 * Grant/revoke fine-grained capabilities. Enforces "no self-grant of
 * CLINICAL_RECORD_*" (RBAC.md separation of duties).
 */
export async function setMemberCapabilities(
  ctx: RequestContext,
  membershipId: string,
  input: z.infer<typeof capabilitiesSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const current = await t.membership.findFirstOrThrow({
    where: { id: membershipId, organizationId: ctx.org!.id },
    select: { id: true, capabilities: true, user: { select: { email: true } } },
  });

  assertCanEditCapabilities(
    ctx,
    membershipId,
    input.capabilities,
    current.capabilities,
  );

  const updated = await t.membership.update({
    where: { id: membershipId },
    data: { capabilities: { set: input.capabilities } },
    select: { id: true, role: true, capabilities: true },
  });

  const added = input.capabilities.filter((c) => !current.capabilities.includes(c));
  const removed = current.capabilities.filter((c) => !input.capabilities.includes(c));
  if (added.length) {
    await writeAudit(ctx, {
      action: "MEMBER_CAPABILITY_GRANTED",
      entityType: "Membership",
      entityId: membershipId,
      after: { granted: added, target: current.user.email },
    });
  }
  if (removed.length) {
    await writeAudit(ctx, {
      action: "MEMBER_CAPABILITY_REVOKED",
      entityType: "Membership",
      entityId: membershipId,
      after: { revoked: removed, target: current.user.email },
    });
  }
  return updated;
}
