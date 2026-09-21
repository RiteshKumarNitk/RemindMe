import type { MembershipCapability, Role } from "@prisma/client";
import { AppError } from "./errors.js";
import type { RequestContext } from "./context.js";

/**
 * Role + capability checks (RBAC.md). A role NEVER implies clinical-record
 * access on its own — that needs a `CLINICAL_RECORD_*` capability (and, for a
 * doctor, a patient relationship checked in the service layer).
 */

export function assertOrg(ctx: RequestContext): asserts ctx is RequestContext & {
  org: NonNullable<RequestContext["org"]>;
} {
  if (!ctx.org) throw new AppError("NOT_AUTHENTICATED", "No clinic context.");
  if (!ctx.org.isActive) {
    throw new AppError("FORBIDDEN", "This clinic is suspended.");
  }
}

export function assertRole(ctx: RequestContext, ...roles: Role[]): void {
  assertOrg(ctx);
  if (!roles.includes(ctx.org.role)) {
    throw new AppError(
      "FORBIDDEN_ROLE",
      `This action requires role: ${roles.join(" or ")}.`,
    );
  }
}

export function hasCapability(
  ctx: RequestContext,
  cap: MembershipCapability,
): boolean {
  return !!ctx.org?.capabilities.includes(cap);
}

export function assertCapability(
  ctx: RequestContext,
  cap: MembershipCapability,
): void {
  assertOrg(ctx);
  if (!ctx.org.capabilities.includes(cap)) {
    throw new AppError(
      "FORBIDDEN",
      `This action requires the ${cap} capability.`,
    );
  }
}

/** Capabilities that MUST NOT be self-granted (separation of duties). */
export const NON_SELF_GRANTABLE: MembershipCapability[] = [
  "CLINICAL_RECORD_READ",
  "CLINICAL_RECORD_WRITE",
];

/**
 * Enforces the "no self-grant of clinical capabilities" rule
 * (RBAC.md / MEDICAL_DATA_SECURITY.md). The acting admin cannot add or remove
 * a CLINICAL_RECORD_* capability on their own membership.
 */
export function assertCanEditCapabilities(
  ctx: RequestContext,
  targetMembershipId: string,
  nextCapabilities: MembershipCapability[],
  currentCapabilities: MembershipCapability[],
): void {
  assertRole(ctx, "CLINIC_ADMIN");
  if (targetMembershipId !== ctx.org!.membershipId) return;

  const added = nextCapabilities.filter((c) => !currentCapabilities.includes(c));
  const removed = currentCapabilities.filter(
    (c) => !nextCapabilities.includes(c),
  );
  const touchedClinical = [...added, ...removed].filter((c) =>
    NON_SELF_GRANTABLE.includes(c),
  );
  if (touchedClinical.length > 0) {
    throw new AppError(
      "CANNOT_SELF_GRANT_CAPABILITY",
      "You cannot grant or revoke a clinical-record capability on your own " +
        "membership. A different clinic admin must do it.",
    );
  }
}
