import type { Role } from "@prisma/client";
import { db } from "./db.js";
import type { RequestContext } from "./context.js";

/**
 * Append-only audit log (MEDICAL_DATA_SECURITY.md "Audit logging").
 * Never store passwords, hashes, tokens, or FCM tokens — callers must pass
 * already-redacted `before`/`after`.
 */
export interface AuditInput {
  action: string; // e.g. "ORGANIZATION_CREATED", "MEMBER_CAPABILITY_GRANTED"
  entityType: string;
  entityId: string;
  before?: unknown;
  after?: unknown;
}

export async function writeAudit(
  ctx: RequestContext,
  input: AuditInput,
): Promise<void> {
  await db.auditLog.create({
    data: {
      organizationId: ctx.org?.id ?? null,
      actorUserId: ctx.userId,
      actorRole: (ctx.org?.role ?? null) as Role | null,
      action: input.action,
      entityType: input.entityType,
      entityId: input.entityId,
      before: input.before === undefined ? undefined : (input.before as object),
      after: input.after === undefined ? undefined : (input.after as object),
      ip: ctx.ip,
      userAgent: ctx.userAgent,
      requestId: ctx.requestId,
    },
  });
}
