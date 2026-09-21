import { json, withApi } from "@/lib/http.js";
import { signConsultation } from "@/modules/consultations/service.js";

export const POST = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await signConsultation(ctx, params.appointmentId!));
});
