import { json, withApi } from "@/lib/http.js";
import { getOrganizationDetail } from "@/modules/superadmin/service.js";

// NOTE: this dynamic segment is deliberately named `targetOrgId`, not
// `orgId` — `withApi()` auto-resolves tenant context from a literal
// `params.orgId`, which would try (and fail, 404) to find the platform
// admin's own membership in the org being inspected. Admin routes bypass
// that entirely; authorization here is `ctx.isPlatformAdmin`, asserted in
// the service.
export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await getOrganizationDetail(ctx, params.targetOrgId!));
});
