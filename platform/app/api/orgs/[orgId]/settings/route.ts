import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { updateSettingsSchema } from "@/modules/clinics/schema.js";
import { getSettings, updateSettings } from "@/modules/clinics/service.js";

export const GET = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ ctx }) => json(await getSettings(ctx)),
);

export const PATCH = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const input = await parseBody(req, updateSettingsSchema);
    return json(await updateSettings(ctx, input));
  },
);
