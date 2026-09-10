import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { createDoctorSchema } from "@/modules/doctors/schema.js";
import { createDoctor, listDoctors } from "@/modules/doctors/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json({ data: await listDoctors(ctx) });
});

export const POST = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const input = await parseBody(req, createDoctorSchema);
    return json(await createDoctor(ctx, input), { status: 201 });
  },
);
