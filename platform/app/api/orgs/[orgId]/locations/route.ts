import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { createLocationSchema } from "@/modules/clinics/schema.js";
import { createLocation, listLocations } from "@/modules/clinics/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json({ data: await listLocations(ctx) });
});

export const POST = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const input = await parseBody(req, createLocationSchema);
    return json(await createLocation(ctx, input), { status: 201 });
  },
);
