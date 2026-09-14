import type { Prisma, PrismaClient, Role } from "@prisma/client";
import { db } from "./db.js";
import type { RequestContext } from "./context.js";

/**
 * Append-only audit log (MEDICAL_DATA_SECURITY.md "Audit logging").
 * Never store passwords, hashes, tokens, or FCM tokens — callers must pass
 * already-redacted `before`/`after`.
 */
export interface AuditInput {
  action: string; // e.g. "APPOINTMENT_CREATED", "MEMBER_CAPABILITY_GRANTED"
  entityType: string;
  entityId: string;
  before?: unknown;
  after?: unknown;
  organizationId?: string | null; // override (e.g. during org bootstrap)
}

type AuditClient = PrismaClient | Prisma.TransactionClient;

export async function writeAuditWith(
  client: AuditClient,
  ctx: RequestContext,
  input: AuditInput,
): Promise<void> {
  await client.auditLog.create({
    data: {
      organizationId:
        input.organizationId !== undefined
          ? input.organizationId
          : (ctx.org?.id ?? null),
      actorUserId: ctx.userId || null,
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

export function writeAudit(ctx: RequestContext, input: AuditInput): Promise<void> {
  return writeAuditWith(db, ctx, input);
}
