import { json, withApi } from "@/lib/http.js";
import { parseQuery, z } from "@/lib/validation.js";
import { listMyFamilyInOrg } from "@/modules/family/service.js";

const querySchema = z.object({ organizationId: z.string().uuid() }).strict();

/**
 * The caller's family members (dependents they may book for) at one clinic.
 *
 * Not under `/api/orgs/:orgId/...` for the same reason as patient booking: a
 * first-time patient has no membership yet. Only ever returns the caller's
 * own grants — `organizationId` just narrows them.
 */
export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, querySchema);
  return json(await listMyFamilyInOrg(ctx.userId, q.organizationId));
});
