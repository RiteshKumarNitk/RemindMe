import type { z } from "zod";
import type { AccessPermission } from "@prisma/client";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import type { createAccessGrantSchema } from "./schema.js";

/**
 * Family / guardian access (spec §15, MEDICAL_DATA_SECURITY.md "Family /
 * dependents"). `FamilyRelationship` records the human relationship only —
 * it grants nothing by itself. `PatientAccessGrant` is the actual permission
 * set, created only by the patient (self-owned) or a CLINIC_ADMIN, and
 * revocable any time. Re-granting to the same grantee reactivates/updates
 * their existing grant rather than creating a duplicate row (unique on
 * patientId+granteeUserId).
 */

const GRANT_SELECT = {
  id: true,
  patientId: true,
  granteeUserId: true,
  granteeUser: { select: { id: true, email: true, fullName: true } },
  permissions: true,
  expiresAt: true,
  revokedAt: true,
  grantedById: true,
  createdAt: true,
} as const;

async function assertCanManage(ctx: RequestContext, patientId: string): Promise<void> {
  const role = ctx.org!.role;
  if (role === "CLINIC_ADMIN") return;
  if (role === "PATIENT") {
    const t = tenantDb(ctx);
    const patient = await t.patient.findFirst({
      where: { id: patientId, organizationId: ctx.org!.id },
      select: { ownerUserId: true },
    });
    if (patient?.ownerUserId === ctx.userId) return;
  }
  throw new AppError("FORBIDDEN", "You cannot manage access for this patient.");
}

export async function listAccessGrants(ctx: RequestContext, patientId: string) {
  await assertCanManage(ctx, patientId);
  const t = tenantDb(ctx);
  const data = await t.patientAccessGrant.findMany({
    where: { patientId, organizationId: ctx.org!.id },
    select: GRANT_SELECT,
    orderBy: { createdAt: "desc" },
  });
  return { data };
}

export async function createAccessGrant(
  ctx: RequestContext,
  patientId: string,
  input: z.infer<typeof createAccessGrantSchema>,
) {
  await assertCanManage(ctx, patientId);
  const t = tenantDb(ctx);
  await t.patient.findFirstOrThrow({
    where: { id: patientId, organizationId: ctx.org!.id },
    select: { id: true },
  });

  const grantee = await db.user.findUnique({
    where: { email: input.granteeEmail.trim().toLowerCase() },
    select: { id: true },
  });
  if (!grantee) {
    throw new AppError("VALIDATION_FAILED", "No platform account exists for that email yet.");
  }
  if (grantee.id === ctx.userId) {
    throw new AppError("VALIDATION_FAILED", "You cannot grant access to yourself.");
  }

  if (input.relation) {
    await t.familyRelationship.upsert({
      where: {
        guardianUserId_dependentPatientId: {
          guardianUserId: grantee.id,
          dependentPatientId: patientId,
        },
      },
      create: {
        organizationId: ctx.org!.id,
        guardianUserId: grantee.id,
        dependentPatientId: patientId,
        relation: input.relation,
        createdById: ctx.userId,
      },
      update: { relation: input.relation },
    });
  }

  const grant = await t.patientAccessGrant.upsert({
    where: { patientId_granteeUserId: { patientId, granteeUserId: grantee.id } },
    create: {
      organizationId: ctx.org!.id,
      patientId,
      granteeUserId: grantee.id,
      permissions: input.permissions as AccessPermission[],
      grantedById: ctx.userId,
      expiresAt: input.expiresAt ? new Date(input.expiresAt) : null,
      revokedAt: null,
    },
    update: {
      permissions: input.permissions as AccessPermission[],
      grantedById: ctx.userId,
      expiresAt: input.expiresAt ? new Date(input.expiresAt) : null,
      revokedAt: null,
    },
    select: GRANT_SELECT,
  });

  await writeAudit(ctx, {
    action: "ACCESS_GRANT_CREATED",
    entityType: "PatientAccessGrant",
    entityId: grant.id,
    after: { granteeUserId: grant.granteeUserId, permissions: grant.permissions },
  });
  return grant;
}

export async function revokeAccessGrant(ctx: RequestContext, patientId: string, grantId: string) {
  await assertCanManage(ctx, patientId);
  const t = tenantDb(ctx);
  const grant = await t.patientAccessGrant.findFirst({
    where: { id: grantId, patientId, organizationId: ctx.org!.id },
  });
  if (!grant) throw new AppError("NOT_FOUND", "Not found.");
  if (grant.revokedAt) return grant;

  const revoked = await t.patientAccessGrant.update({
    where: { id: grantId },
    data: { revokedAt: new Date() },
    select: GRANT_SELECT,
  });
  await writeAudit(ctx, {
    action: "ACCESS_GRANT_REVOKED",
    entityType: "PatientAccessGrant",
    entityId: grantId,
  });
  return revoked;
}

/** Patients the caller can access as a family member/guardian ("my access"). */
export async function listMyAccess(ctx: RequestContext) {
  const t = tenantDb(ctx);
  const data = await t.patientAccessGrant.findMany({
    where: {
      organizationId: ctx.org!.id,
      granteeUserId: ctx.userId,
      revokedAt: null,
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
    },
    select: {
      id: true,
      permissions: true,
      expiresAt: true,
      patient: { select: { id: true, firstName: true, lastName: true } },
    },
    orderBy: { createdAt: "desc" },
  });
  return { data };
}

/**
 * Same as `listMyAccess`, but callable *before* the caller has a `Membership`
 * in `organizationId` — used by the public self-booking flow to offer a
 * "book for myself / a dependent" picker on first visit to a clinic. Safe
 * without tenant scoping because `granteeUserId` is always the authenticated
 * caller's own id, never client-supplied — this can only ever return the
 * caller's own grants, in any org, regardless of their membership there.
 */
export async function listMyAccessInOrg(userId: string, organizationId: string) {
  const data = await db.patientAccessGrant.findMany({
    where: {
      organizationId,
      granteeUserId: userId,
      revokedAt: null,
      permissions: { has: "MANAGE_APPOINTMENTS" },
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
    },
    select: {
      id: true,
      permissions: true,
      patient: { select: { id: true, firstName: true, lastName: true } },
    },
    orderBy: { createdAt: "desc" },
  });
  return data;
}

/**
 * Does the caller hold an active, non-expired grant on this patient covering
 * `permission`? Used by other modules (patients, consultations) as the 4th
 * access path in MEDICAL_DATA_SECURITY.md's access model. `VIEW_MEDICATIONS`
 * is treated as covering consultation notes too — the schema has no separate
 * "view consultation" permission and a consultation's own GET already bundles
 * its prescriptions.
 */
export async function hasFamilyAccess(
  ctx: RequestContext,
  patientId: string,
  permission: AccessPermission,
): Promise<boolean> {
  if (!ctx.userId || !ctx.org) return false;
  const t = tenantDb(ctx);
  const grant = await t.patientAccessGrant.findFirst({
    where: {
      patientId,
      organizationId: ctx.org.id,
      granteeUserId: ctx.userId,
      revokedAt: null,
      permissions: { has: permission },
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
    },
    select: { id: true },
  });
  return !!grant;
}
