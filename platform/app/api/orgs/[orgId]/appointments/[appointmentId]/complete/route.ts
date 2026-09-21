import { json, withApi } from "@/lib/http.js";
import { completeConsultation } from "@/modules/appointments/service.js";

export const POST = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await completeConsultation(ctx, params.appointmentId!));
});
