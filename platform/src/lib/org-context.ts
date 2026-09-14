import { db } from "./db.js";
import type { OrgContext } from "./context.js";

/**
 * Resolve `:orgId` against the caller's ACTIVE memberships (MULTI_TENANCY.md
 * — the only trusted tenant selector). Shared by the API pipeline
 * (`http.ts`) and the web app's server-side auth (`web-context.ts`) so both
 * paths enforce the exact same guarantee.
 */
export async function resolveOrgContext(
  userId: string,
  orgId: string,
): Promise<OrgContext | null> {
  const membership = await db.membership.findFirst({
    where: { userId, organizationId: orgId, status: "ACTIVE" },
    include: { organization: { select: { isActive: true } } },
  });
  if (!membership) return null;
  return {
    id: orgId,
    membershipId: membership.id,
    role: membership.role,
    capabilities: membership.capabilities,
    isActive: membership.organization.isActive,
  };
}
