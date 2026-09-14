import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { createTypeSchema } from "@/modules/appointments/schema.js";
import {
  createAppointmentType,
  listAppointmentTypes,
} from "@/modules/appointments/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json({ data: await listAppointmentTypes(ctx) });
});

export const POST = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const input = await parseBody(req, createTypeSchema);
    return json(await createAppointmentType(ctx, input), { status: 201 });
  },
);
