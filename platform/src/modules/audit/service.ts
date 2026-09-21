import type { z } from "zod";
import { assertRole } from "@/lib/rbac.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import type { listAuditQuerySchema } from "./schema.js";

/** Read-only audit trail (MEDICAL_DATA_SECURITY.md, spec §22). Own org only. */
export async function listAuditLog(ctx: RequestContext, q: z.infer<typeof listAuditQuerySchema>) {
  assertRole(ctx, "CLINIC_ADMIN");
  const t = tenantDb(ctx);
  const data = await t.auditLog.findMany({
    where: {
      organizationId: ctx.org!.id,
      ...(q.entityType ? { entityType: q.entityType } : {}),
      ...(q.entityId ? { entityId: q.entityId } : {}),
    },
    orderBy: { at: "desc" },
    take: q.limit,
  });
  return { data };
}
