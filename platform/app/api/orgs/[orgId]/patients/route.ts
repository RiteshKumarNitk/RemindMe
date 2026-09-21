import { json, withApi } from "@/lib/http.js";
import { parseBody, parseQuery } from "@/lib/validation.js";
import { createPatientSchema, listPatientsQuerySchema } from "@/modules/patients/schema.js";
import { createPatient, listPatients } from "@/modules/patients/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, listPatientsQuerySchema);
  return json(await listPatients(ctx, q));
});

export const POST = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, createPatientSchema);
  return json(await createPatient(ctx, input), { status: 201 });
});
