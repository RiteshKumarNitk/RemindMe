import { json, withApi } from "@/lib/http.js";
import { confirmAppointment } from "@/modules/appointments/service.js";

export const POST = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await confirmAppointment(ctx, params.appointmentId!));
});
