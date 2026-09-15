import type { Prisma } from "@prisma/client";
import type { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import type { RequestContext } from "@/lib/context.js";
import type {
  listOrganizationsQuerySchema,
  listPlatformAuditQuerySchema,
} from "./schema.js";

/**
 * Platform-admin operations (SYSTEM_ARCHITECTURE.md: "the unscoped client is
 * available only to auth, tenancy, and SUPER_ADMIN platform operations, each
 * with its own guard"). Every function here uses the BASE `db` client, not
 * `tenantDb()` — that's deliberate, this is the one surface allowed to see
 * across tenants — and every function re-asserts `isPlatformAdmin` itself
 * rather than trusting the caller (defense in depth, same pattern every
 * other module uses for its own role checks).
 *
 * Never touches clinical data (Consultation/Prescription/MedicalDocument/
 * Medication/VitalReading bodies) — only tenancy/membership/audit metadata.
 */

function assertSuperAdmin(ctx: RequestContext): void {
  if (!ctx.isPlatformAdmin) {
    throw new AppError("FORBIDDEN_ROLE", "Platform admin only.");
  }
}

const ORG_LIST_SELECT = {
  id: true,
  name: true,
  slug: true,
  isActive: true,
  timezone: true,
  createdAt: true,
  _count: { select: { memberships: true, patients: true, appointments: true } },
} satisfies Prisma.OrganizationSelect;

export async function listOrganizations(
  ctx: RequestContext,
  q: z.infer<typeof listOrganizationsQuerySchema>,
) {
  assertSuperAdmin(ctx);
  const where: Prisma.OrganizationWhereInput = {};
  if (q.status === "active") where.isActive = true;
  if (q.status === "suspended") where.isActive = false;
  if (q.q) {
    const term = q.q.trim();
    where.OR = [
      { name: { contains: term, mode: "insensitive" } },
      { slug: { contains: term, mode: "insensitive" } },
    ];
  }
  const data = await db.organization.findMany({
    where,
    select: ORG_LIST_SELECT,
    orderBy: { createdAt: "desc" },
    take: q.limit,
  });
  return { data };
}

export async function getOrganizationDetail(ctx: RequestContext, orgId: string) {
  assertSuperAdmin(ctx);
  const org = await db.organization.findUniqueOrThrow({
    where: { id: orgId },
    select: {
      id: true,
      name: true,
      slug: true,
      isActive: true,
      timezone: true,
      createdAt: true,
      updatedAt: true,
      _count: {
        select: {
          memberships: true,
          patients: true,
          appointments: true,
          doctorProfiles: true,
          staffProfiles: true,
        },
      },
    },
  });
  const memberships = await db.membership.findMany({
    where: { organizationId: orgId },
    select: {
      id: true,
      role: true,
      status: true,
      createdAt: true,
      user: { select: { id: true, email: true, fullName: true } },
    },
    orderBy: { createdAt: "asc" },
  });
  return { org, memberships };
}

export async function setOrganizationActive(
  ctx: RequestContext,
  orgId: string,
  isActive: boolean,
) {
  assertSuperAdmin(ctx);
  const org = await db.organization.update({
    where: { id: orgId },
    data: { isActive },
    select: { id: true, name: true, isActive: true },
  });
  await writeAudit(ctx, {
    action: isActive ? "ORGANIZATION_REACTIVATED" : "ORGANIZATION_SUSPENDED",
    entityType: "Organization",
    entityId: org.id,
    organizationId: org.id,
    after: { isActive },
  });
  return org;
}

export async function listPlatformAuditLog(
  ctx: RequestContext,
  q: z.infer<typeof listPlatformAuditQuerySchema>,
) {
  assertSuperAdmin(ctx);
  const data = await db.auditLog.findMany({
    select: {
      id: true,
      action: true,
      entityType: true,
      entityId: true,
      actorUserId: true,
      actorRole: true,
      at: true,
      organization: { select: { id: true, name: true } },
    },
    orderBy: { at: "desc" },
    take: q.limit,
  });
  return { data };
}

export async function platformStats(ctx: RequestContext) {
  assertSuperAdmin(ctx);
  const [organizations, activeOrganizations, users, appointments, patients] =
    await Promise.all([
      db.organization.count(),
      db.organization.count({ where: { isActive: true } }),
      db.user.count(),
      db.appointment.count(),
      db.patient.count(),
    ]);
  return { organizations, activeOrganizations, users, appointments, patients };
}
