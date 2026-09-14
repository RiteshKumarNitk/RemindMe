import { json, withApi } from "@/lib/http.js";
import { getPatient } from "@/modules/patients/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await getPatient(ctx, params.patientId!));
});
