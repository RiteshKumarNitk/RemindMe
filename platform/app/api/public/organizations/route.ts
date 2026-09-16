import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listPublicOrganizationsQuerySchema } from "@/modules/public/schema.js";
import { listPublicOrganizations } from "@/modules/public/service.js";

export const GET = withApi({ auth: "none" }, async ({ req }) => {
  const q = parseQuery(req.url, listPublicOrganizationsQuerySchema);
  return json(await listPublicOrganizations(q));
});
