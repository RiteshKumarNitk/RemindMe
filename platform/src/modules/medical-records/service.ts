import type { z } from "zod";
import type { Prisma } from "@prisma/client";
import { tenantDb } from "@/lib/db.js";
import { paginate } from "@/lib/pagination.js";
import type { RequestContext } from "@/lib/context.js";
import type { listConsultationsQuerySchema, listPrescriptionsQuerySchema } from "./schema.js";

export async function listConsultations(
  ctx: RequestContext,
  q: z.infer<typeof listConsultationsQuerySchema>,
) {
  const t = tenantDb(ctx);
  const where: Prisma.ConsultationWhereInput = { organizationId: ctx.org!.id };
  if (q.doctorId) where.doctorId = q.doctorId;
  if (q.patientId) where.patientId = q.patientId;

  // A PATIENT only ever sees their own records, plus any dependent's
  // they hold an active VIEW_DOCUMENTS grant for.
  if (ctx.org!.role === "PATIENT") {
    const familyGrants = await t.patientAccessGrant.findMany({
      where: {
        organizationId: ctx.org!.id,
        granteeUserId: ctx.userId,
        revokedAt: null,
        permissions: { has: "VIEW_DOCUMENTS" },
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      select: { patientId: true },
    });
    const familyPatientIds = familyGrants.map((g) => g.patientId);
    where.patient = familyPatientIds.length
      ? { OR: [{ ownerUserId: ctx.userId }, { id: { in: familyPatientIds } }] }
      : { ownerUserId: ctx.userId };
  }

  const data = await t.consultation.findMany({
    where,
    orderBy: { signedAt: "desc" },
    skip: (q.page - 1) * q.pageSize,
    take: q.pageSize,
    include: {
      patient: { select: { firstName: true, lastName: true } },
      doctor: { select: { displayName: true } },
    }
  });
  const total = await t.consultation.count({ where });
  return paginate(data, total, q.page, q.pageSize);
}

export async function listPrescriptions(
  ctx: RequestContext,
  q: z.infer<typeof listPrescriptionsQuerySchema>,
) {
  const t = tenantDb(ctx);
  const where: Prisma.PrescriptionWhereInput = { organizationId: ctx.org!.id };
  if (q.doctorId) where.doctorId = q.doctorId;
  if (q.patientId) where.patientId = q.patientId;

  if (ctx.org!.role === "PATIENT") {
    const familyGrants = await t.patientAccessGrant.findMany({
      where: {
        organizationId: ctx.org!.id,
        granteeUserId: ctx.userId,
        revokedAt: null,
        permissions: { has: "VIEW_DOCUMENTS" },
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      select: { patientId: true },
    });
    const familyPatientIds = familyGrants.map((g) => g.patientId);
    where.patient = familyPatientIds.length
      ? { OR: [{ ownerUserId: ctx.userId }, { id: { in: familyPatientIds } }] }
      : { ownerUserId: ctx.userId };
  }

  const data = await t.prescription.findMany({
    where,
    orderBy: { issuedAt: "desc" },
    skip: (q.page - 1) * q.pageSize,
    take: q.pageSize,
    include: {
      items: true,
      patient: { select: { firstName: true, lastName: true } },
      doctor: { select: { displayName: true } },
    }
  });
  const total = await t.prescription.count({ where });
  return paginate(data, total, q.page, q.pageSize);
}
