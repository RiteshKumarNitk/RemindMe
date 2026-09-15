import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listOrganizationsQuerySchema } from "@/modules/superadmin/schema.js";
import { listOrganizations } from "@/modules/superadmin/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, listOrganizationsQuerySchema);
  return json(await listOrganizations(ctx, q));
});
