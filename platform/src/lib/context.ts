import type { MembershipCapability, Role } from "@prisma/client";

/**
 * Everything a request handler is allowed to know about "who" and "where".
 * Built by the HTTP pipeline (src/lib/http.ts). Never trusts client-supplied
 * tenant identifiers — `org` is derived from a Membership row.
 */
export interface OrgContext {
  id: string;
  membershipId: string;
  role: Role;
  capabilities: MembershipCapability[];
  isActive: boolean;
}

export interface RequestContext {
  userId: string;
  isPlatformAdmin: boolean;
  isGuest: boolean;
  requestId: string;
  ip: string | null;
  userAgent: string | null;
  /** Present only on `/api/orgs/:orgId/...` routes. */
  org?: OrgContext;
}

/** Narrow to a context that definitely has an org (after the pipeline's check). */
export function requireOrg(ctx: RequestContext): asserts ctx is RequestContext & {
  org: OrgContext;
} {
  if (!ctx.org) {
    throw new Error("requireOrg: called on a non-tenant route (bug in wiring)");
  }
}
