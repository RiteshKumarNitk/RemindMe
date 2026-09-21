import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { setOrganizationActiveSchema } from "@/modules/superadmin/schema.js";
import { setOrganizationActive } from "@/modules/superadmin/service.js";

export const PUT = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, setOrganizationActiveSchema);
  return json(await setOrganizationActive(ctx, params.targetOrgId!, input.isActive));
});
