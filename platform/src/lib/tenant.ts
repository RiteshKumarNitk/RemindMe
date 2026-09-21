import { Prisma } from "@prisma/client";
import { db } from "./db.js";
import { AppError } from "./errors.js";
import type { OrgContext, RequestContext } from "./context.js";

/**
 * Tenant-scoped Prisma client (MULTI_TENANCY.md "Enforcement — layer 1").
 *
 * Every read/write of a tenant-owned model is force-filtered / force-stamped
 * with `organizationId = ctx.org.id`. A caller that passes a *different*
 * `organizationId` gets a 403 — the client can never widen scope.
 *
 * CONVENTION: the scoped client does NOT expose `findUnique` semantics for
 * tenant models (Prisma forbids non-unique filters there). Modules use
 * `findFirst` / `findFirstOrThrow` with `{ id }` instead — the extension adds
 * the org filter, so a cross-tenant id resolves to "not found".
 */

// model name -> the column that carries the tenant id ("id" for Organization).
const SCOPE_FIELD: Record<string, "id" | "organizationId"> = {
  Organization: "id",
  ClinicSettings: "organizationId",
  ClinicLocation: "organizationId",
  Membership: "organizationId",
  DoctorProfile: "organizationId",
  StaffProfile: "organizationId",
  Patient: "organizationId",
  FamilyRelationship: "organizationId",
  PatientAccessGrant: "organizationId",
  Invitation: "organizationId",
  AppointmentType: "organizationId",
  AvailabilityRule: "organizationId",
  AvailabilityException: "organizationId",
  Appointment: "organizationId",
  AppointmentEvent: "organizationId",
  QueueEntry: "organizationId",
  Consultation: "organizationId",
  Prescription: "organizationId",
  MedicalDocument: "organizationId",
  Medication: "organizationId",
  MedicationDose: "organizationId",
  VitalReading: "organizationId",
  Notification: "organizationId",
  AuditLog: "organizationId",
};

const READS = new Set([
  "findFirst",
  "findFirstOrThrow",
  "findMany",
  "count",
  "aggregate",
  "groupBy",
]);
const WHERE_WRITES = new Set(["update", "updateMany", "delete", "deleteMany"]);

function mergeWhere(
  args: { where?: Record<string, unknown> } | undefined,
  field: string,
  value: string,
): Record<string, unknown> {
  const a = (args ?? {}) as { where?: Record<string, unknown> };
  const existing = a.where ?? {};
  const already = existing[field];
  if (already !== undefined && already !== value) {
    throw new AppError(
      "FORBIDDEN",
      "Cross-tenant access is not permitted.",
      undefined,
    );
  }
  return { ...a, where: { ...existing, [field]: value } };
}

function stampData(
  data: Record<string, unknown> | Record<string, unknown>[],
  field: string,
  value: string,
) {
  const one = (d: Record<string, unknown>) => {
    if (d[field] !== undefined && d[field] !== value) {
      throw new AppError(
        "FORBIDDEN",
        "Cross-tenant write is not permitted.",
        undefined,
      );
    }
    d[field] = value;
  };
  if (Array.isArray(data)) data.forEach(one);
  else one(data);
}

export type TenantDb = ReturnType<typeof buildTenantDb>;

function buildTenantDb(orgId: string) {
  return db.$extends({
    name: "tenant-scope",
    query: {
      $allModels: {
        $allOperations({ model, operation, args, query }) {
          const field = SCOPE_FIELD[model];
          if (!field) return query(args); // non-tenant / child model

          if (operation === "findUnique" || operation === "findUniqueOrThrow") {
            throw new AppError(
              "INTERNAL",
              `tenantDb: use findFirst instead of ${operation} for ${model}`,
            );
          }

          if (READS.has(operation) || WHERE_WRITES.has(operation)) {
            return query(mergeWhere(args as never, field, orgId) as never);
          }

          if (operation === "create") {
            const a = args as { data?: Record<string, unknown> };
            if (a.data) stampData(a.data, field, orgId);
            return query(args);
          }
          if (operation === "createMany" || operation === "createManyAndReturn") {
            const a = args as { data?: Record<string, unknown> | Record<string, unknown>[] };
            if (a.data) stampData(a.data, field, orgId);
            return query(args);
          }
          if (operation === "upsert") {
            const a = args as {
              where?: Record<string, unknown>;
              create?: Record<string, unknown>;
            };
            if (a.create) stampData(a.create, field, orgId);
            return query(mergeWhere(a as never, field, orgId) as never);
          }

          return query(args);
        },
      },
    },
  });
}

/** The tenant-scoped client for a request that has resolved an org. */
export function tenantDb(ctx: RequestContext): TenantDb {
  if (!ctx.org) {
    throw new AppError("INTERNAL", "tenantDb: no org on context");
  }
  return buildTenantDb(ctx.org.id);
}

/** Same, from a bare org id (used by seed / tests). */
export function tenantDbForOrg(org: Pick<OrgContext, "id">): TenantDb {
  return buildTenantDb(org.id);
}

export { Prisma };
