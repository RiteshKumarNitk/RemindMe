import { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import { resolveMemberUser } from "@/modules/doctors/service.js";
import type { RequestContext } from "@/lib/context.js";
import type { createStaffSchema } from "@/modules/doctors/schema.js";

export async function listStaff(ctx: RequestContext) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  return t.staffProfile.findMany({
    where: { organizationId: ctx.org!.id },
    orderBy: { createdAt: "asc" },
    select: {
      id: true,
      jobTitle: true,
      isActive: true,
      userId: true,
      createdAt: true,
    },
  });
}

export async function createStaff(
  ctx: RequestContext,
  input: z.infer<typeof createStaffSchema>,
) {
  assertRole(ctx, "CLINIC_ADMIN");
  const userId = await resolveMemberUser(ctx, "RECEPTIONIST", input);

  const existing = await db.staffProfile.findFirst({
    where: { organizationId: ctx.org!.id, userId },
    select: { id: true },
  });
  if (existing) {
    throw new AppError("CONFLICT", "That person is already staff here.");
  }

  const t = tenantDb(ctx);
  const staff = await t.staffProfile.create({
    data: { organizationId: ctx.org!.id, userId, jobTitle: input.jobTitle ?? null },
  });
  await writeAudit(ctx, {
    action: "STAFF_CREATED",
    entityType: "StaffProfile",
    entityId: staff.id,
    after: { jobTitle: staff.jobTitle, userId },
  });
  return staff;
}
