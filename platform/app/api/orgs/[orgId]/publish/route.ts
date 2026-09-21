import { json, withApi } from "@/lib/http.js";
import { publishOrganization } from "@/modules/clinics/service.js";

export const POST = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ ctx }) => {
    return json(await publishOrganization(ctx));
  },
);
