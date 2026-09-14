import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { saveConsultationSchema } from "@/modules/consultations/schema.js";
import { getConsultation, saveConsultation } from "@/modules/consultations/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await getConsultation(ctx, params.appointmentId!));
});

export const PUT = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, saveConsultationSchema);
  return json(await saveConsultation(ctx, params.appointmentId!, input));
});
