import { PrismaClient } from "@prisma/client";
import { env } from "./env.js";

/**
 * Base (unscoped) Prisma client. Use this ONLY for:
 *  - non-tenant models: User, Session, RefreshToken, IdentityAccount
 *  - auth, org bootstrap (tenancy.createOrganization), platform-admin paths
 *  - writing AuditLog rows
 *
 * Everything else goes through `tenantClient(ctx)` (see ./tenant.ts), which
 * forces `organizationId` onto every query.
 */
const globalForPrisma = globalThis as unknown as { __prisma?: PrismaClient };

export const db =
  globalForPrisma.__prisma ??
  new PrismaClient({
    log: env.LOG_LEVEL === "debug" ? ["query", "warn", "error"] : ["warn", "error"],
  });

if (env.NODE_ENV !== "production") globalForPrisma.__prisma = db;
