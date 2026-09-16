import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { setOrganizationVerificationSchema } from "@/modules/superadmin/schema.js";
import { setOrganizationVerification } from "@/modules/superadmin/service.js";

export const PUT = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, setOrganizationVerificationSchema);
  return json(await setOrganizationVerification(ctx, params.targetOrgId!, input));
});
