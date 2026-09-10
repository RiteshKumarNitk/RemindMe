import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { capabilitiesSchema } from "@/modules/clinics/schema.js";
import { setMemberCapabilities } from "@/modules/clinics/service.js";

export const PUT = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx, params }) => {
    const input = await parseBody(req, capabilitiesSchema);
    return json(await setMemberCapabilities(ctx, params.membershipId!, input));
  },
);
