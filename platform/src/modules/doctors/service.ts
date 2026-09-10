import { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import type { createDoctorSchema, updateDoctorSchema } from "./schema.js";

/** Resolve or create a User for a staff/doctor row, and ensure a membership. */
async function resolveMemberUser(
  ctx: RequestContext,
  role: "DOCTOR" | "RECEPTIONIST",
  input: { userId?: string; email?: string; fullName?: string },
): Promise<string> {
  return db.$transaction(async (tx) => {
    let userId = input.userId;
    if (!userId) {
      const email = input.email!.trim().toLowerCase();
      const user =
        (await tx.user.findUnique({ where: { email }, select: { id: true } })) ??
        (await tx.user.create({
          data: { email, fullName: input.fullName!.trim() },
          select: { id: true },
        }));
      userId = user.id;
    }
    const membership = await tx.membership.findFirst({
      where: { userId, organizationId: ctx.org!.id, role },
      select: { id: true },
    });
    if (!membership) {
      await tx.membership.create({
        data: {
          userId,
          organizationId: ctx.org!.id,
          role,
          status: "ACTIVE",
          invitedById: ctx.userId,
        },
      });
    }
    return userId;
  });
}

export async function listDoctors(ctx: RequestContext) {
  const t = tenantDb(ctx);
  return t.doctorProfile.findMany({
    where: { organizationId: ctx.org!.id },
    orderBy: { displayName: "asc" },
  });
}

export async function getDoctor(ctx: RequestContext, doctorId: string) {
  const t = tenantDb(ctx);
  return t.doctorProfile.findFirstOrThrow({
    where: { id: doctorId, organizationId: ctx.org!.id },
  });
}

export async function createDoctor(
  ctx: RequestContext,
  input: z.infer<typeof createDoctorSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const userId = await resolveMemberUser(ctx, "DOCTOR", input);

  const existing = await db.doctorProfile.findFirst({
    where: { organizationId: ctx.org!.id, userId },
    select: { id: true },
  });
  if (existing) {
    throw new AppError("CONFLICT", "That person is already a doctor here.");
  }

  const t = tenantDb(ctx);
  const doc = await t.doctorProfile.create({
    data: {
      organizationId: ctx.org!.id,
      userId,
      displayName: input.displayName.trim(),
      specialty: input.specialty ?? null,
      registrationNumber: input.registrationNumber ?? null,
      bio: input.bio ?? null,
      consultationDurationMin: input.consultationDurationMin,
      isAcceptingNewPatients: input.isAcceptingNewPatients,
    },
  });
  await writeAudit(ctx, {
    action: "DOCTOR_CREATED",
    entityType: "DoctorProfile",
    entityId: doc.id,
    after: { displayName: doc.displayName, userId },
  });
  return doc;
}

export async function updateDoctor(
  ctx: RequestContext,
  doctorId: string,
  input: z.infer<typeof updateDoctorSchema>,
) {
  // A doctor may edit their own profile; an admin may edit any.
  const t = tenantDb(ctx);
  const current = await t.doctorProfile.findFirstOrThrow({
    where: { id: doctorId, organizationId: ctx.org!.id },
    select: { id: true, userId: true },
  });
  const isSelf = current.userId === ctx.userId;
  if (!isSelf) assertRole(ctx, "CLINIC_ADMIN");
  if (isSelf && input.isActive === false && ctx.org!.role !== "CLINIC_ADMIN") {
    throw new AppError("FORBIDDEN", "Only an admin can deactivate a doctor.");
  }

  const updated = await t.doctorProfile.update({
    where: { id: doctorId },
    data: {
      ...(input.displayName !== undefined ? { displayName: input.displayName.trim() } : {}),
      ...(input.specialty !== undefined ? { specialty: input.specialty } : {}),
      ...(input.registrationNumber !== undefined
        ? { registrationNumber: input.registrationNumber }
        : {}),
      ...(input.bio !== undefined ? { bio: input.bio } : {}),
      ...(input.consultationDurationMin !== undefined
        ? { consultationDurationMin: input.consultationDurationMin }
        : {}),
      ...(input.isAcceptingNewPatients !== undefined
        ? { isAcceptingNewPatients: input.isAcceptingNewPatients }
        : {}),
      ...(input.isActive !== undefined ? { isActive: input.isActive } : {}),
    },
  });
  await writeAudit(ctx, {
    action: "DOCTOR_UPDATED",
    entityType: "DoctorProfile",
    entityId: doctorId,
    after: { displayName: updated.displayName, isActive: updated.isActive },
  });
  return updated;
}

export { resolveMemberUser };
