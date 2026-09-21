import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { updateDoctorSchema } from "@/modules/doctors/schema.js";
import { getDoctor, updateDoctor } from "@/modules/doctors/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await getDoctor(ctx, params.doctorId!));
});

export const PATCH = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, updateDoctorSchema);
  return json(await updateDoctor(ctx, params.doctorId!, input));
});
