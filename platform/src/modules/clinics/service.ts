import { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { assertRole, assertCanEditCapabilities } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import { canPublishOrganization } from "./publish.js";
import type {
  capabilitiesSchema,
  createLocationSchema,
  inviteMemberSchema,
  updateMemberSchema,
  updateOrgSchema,
  updateSettingsSchema,
} from "./schema.js";

const PUBLIC_PROFILE_SELECT = {
  id: true,
  name: true,
  slug: true,
  timezone: true,
  isActive: true,
  createdAt: true,
  orgType: true,
  tagline: true,
  about: true,
  logoUrl: true,
  coverImageUrl: true,
  publicPhone: true,
  publicEmail: true,
  website: true,
  verificationStatus: true,
  isPubliclyListed: true,
} as const;

export async function getOrganization(ctx: RequestContext) {
  const t = tenantDb(ctx);
  const org = await t.organization.findFirstOrThrow({
    where: { id: ctx.org!.id },
    select: {
      ...PUBLIC_PROFILE_SELECT,
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
      ...(input.orgType !== undefined ? { orgType: input.orgType } : {}),
      ...(input.tagline !== undefined ? { tagline: input.tagline?.trim() || null } : {}),
      ...(input.about !== undefined ? { about: input.about?.trim() || null } : {}),
      ...(input.logoUrl !== undefined ? { logoUrl: input.logoUrl } : {}),
      ...(input.coverImageUrl !== undefined ? { coverImageUrl: input.coverImageUrl } : {}),
      ...(input.publicPhone !== undefined ? { publicPhone: input.publicPhone?.trim() || null } : {}),
      ...(input.publicEmail !== undefined
        ? { publicEmail: input.publicEmail?.trim().toLowerCase() || null }
        : {}),
      ...(input.website !== undefined ? { website: input.website } : {}),
    },
    select: PUBLIC_PROFILE_SELECT,
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

/**
 * Flip the org's public-discovery listing on/off. Publishing does NOT grant
 * `verificationStatus: VERIFIED` — verification is a separate, later,
 * platform-reviewed concern (PRODUCT_EVOLUTION_PLAN.md §11/§15 Phase 10). An
 * org can be publicly listed while still `DRAFT`-verified; discovery pages
 * (Phase 5) must render an "unverified" state honestly, never a fake badge.
 */
export async function publishOrganization(ctx: RequestContext) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const org = await t.organization.findFirstOrThrow({
    where: { id: ctx.org!.id },
    select: { ...PUBLIC_PROFILE_SELECT, _count: { select: { locations: { where: { isActive: true } } } } },
  });

  const readiness = canPublishOrganization({
    name: org.name,
    orgType: org.orgType,
    tagline: org.tagline,
    about: org.about,
    publicPhone: org.publicPhone,
    publicEmail: org.publicEmail,
    activeLocationCount: org._count.locations,
  });
  if (!readiness.ready) {
    throw new AppError("VALIDATION_FAILED", readiness.reasons.join(" "));
  }

  const updated = await t.organization.update({
    where: { id: ctx.org!.id },
    data: { isPubliclyListed: true },
    select: PUBLIC_PROFILE_SELECT,
  });
  await writeAudit(ctx, {
    action: "ORGANIZATION_PUBLISHED",
    entityType: "Organization",
    entityId: updated.id,
    after: { isPubliclyListed: true },
  });
  return updated;
}

export async function unpublishOrganization(ctx: RequestContext) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const updated = await t.organization.update({
    where: { id: ctx.org!.id },
    data: { isPubliclyListed: false },
    select: PUBLIC_PROFILE_SELECT,
  });
  await writeAudit(ctx, {
    action: "ORGANIZATION_UNPUBLISHED",
    entityType: "Organization",
    entityId: updated.id,
    after: { isPubliclyListed: false },
  });
  return updated;
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
