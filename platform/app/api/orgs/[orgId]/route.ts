import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { updateOrgSchema } from "@/modules/clinics/schema.js";
import { getOrganization, updateOrganization } from "@/modules/clinics/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json(await getOrganization(ctx));
});

export const PATCH = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const input = await parseBody(req, updateOrgSchema);
    return json(await updateOrganization(ctx, input));
  },
);
