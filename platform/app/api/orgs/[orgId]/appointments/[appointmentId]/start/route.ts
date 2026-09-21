import { json, withApi } from "@/lib/http.js";
import { startConsultation } from "@/modules/appointments/service.js";

export const POST = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await startConsultation(ctx, params.appointmentId!));
});
