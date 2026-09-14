import type { Prisma } from "@prisma/client";
import { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import { hasFamilyAccess } from "@/modules/family/service.js";
import type { RequestContext } from "@/lib/context.js";
import type { createPatientSchema, listPatientsQuerySchema } from "./schema.js";

/**
 * Minimal patient records (spec §7 "Patients"). Demographics only — no
 * clinical fields, no family/access-grant model yet (Phase 3 proper). Exists
 * because booking an appointment requires a `patientId`, and nothing could
 * create one before this.
 */

const PATIENT_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  phone: true,
  email: true,
  dateOfBirth: true,
  sex: true,
  mrn: true,
  ownerUserId: true,
  isActive: true,
  createdAt: true,
} as const;

export async function listPatients(
  ctx: RequestContext,
  q: z.infer<typeof listPatientsQuerySchema>,
) {
  const t = tenantDb(ctx);
  const orgId = ctx.org!.id;

  if (ctx.org!.role === "PATIENT") {
    const data = await t.patient.findMany({
      where: { organizationId: orgId, ownerUserId: ctx.userId },
      select: PATIENT_SELECT,
      orderBy: { firstName: "asc" },
    });
    return { data };
  }

  assertRole(ctx, "DOCTOR", "RECEPTIONIST", "CLINIC_ADMIN");
  const where: Prisma.PatientWhereInput = { organizationId: orgId, isActive: true };
  if (q.q) {
    const term = q.q.trim();
    where.OR = [
      { firstName: { contains: term, mode: "insensitive" } },
      { lastName: { contains: term, mode: "insensitive" } },
      { phone: { contains: term } },
      { mrn: { contains: term, mode: "insensitive" } },
    ];
  }
  const data = await t.patient.findMany({
    where,
    select: PATIENT_SELECT,
    orderBy: { firstName: "asc" },
    take: q.limit,
  });
  return { data };
}

export async function getPatient(ctx: RequestContext, id: string) {
  const t = tenantDb(ctx);
  const patient = await t.patient.findFirstOrThrow({
    where: { id, organizationId: ctx.org!.id },
    select: PATIENT_SELECT,
  });
  if (ctx.org!.role === "PATIENT" && patient.ownerUserId !== ctx.userId) {
    if (!(await hasFamilyAccess(ctx, id, "VIEW_PROFILE"))) {
      throw new AppError("FORBIDDEN", "You can only view your own record.");
    }
  }
  return patient;
}

export async function createPatient(
  ctx: RequestContext,
  input: z.infer<typeof createPatientSchema>,
) {
  assertRole(ctx, "RECEPTIONIST", "CLINIC_ADMIN");

  let ownerUserId: string | null = null;
  if (input.ownerEmail) {
    const owner = await db.user.findUnique({
      where: { email: input.ownerEmail.trim().toLowerCase() },
      select: { id: true },
    });
    ownerUserId = owner?.id ?? null;
  }

  const t = tenantDb(ctx);
  const patient = await t.patient.create({
    data: {
      organizationId: ctx.org!.id,
      firstName: input.firstName.trim(),
      lastName: input.lastName.trim(),
      phone: input.phone ?? null,
      email: input.email ?? null,
      dateOfBirth: input.dateOfBirth ? new Date(`${input.dateOfBirth}T00:00:00Z`) : null,
      sex: input.sex ?? null,
      mrn: input.mrn ?? null,
      notes: input.notes ?? null,
      ownerUserId,
      createdById: ctx.userId,
    },
    select: PATIENT_SELECT,
  });
  await writeAudit(ctx, {
    action: "PATIENT_CREATED",
    entityType: "Patient",
    entityId: patient.id,
    after: { firstName: patient.firstName, lastName: patient.lastName },
  });
  return patient;
}
