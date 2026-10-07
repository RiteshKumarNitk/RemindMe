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
    // Prisma's defaults (5 s run, 2 s to acquire a connection) are too tight
    // for multi-query interactive transactions like booking when the database
    // round trip is slow — an expired transaction surfaced as a generic 500
    // "couldn't book". Functions are pinned next to the DB (vercel.json
    // regions); this is the safety margin on top.
    transactionOptions: { maxWait: 10_000, timeout: 20_000 },
  });

if (env.NODE_ENV !== "production") globalForPrisma.__prisma = db;
