import { json, withApi } from "@/lib/http.js";
import { noShowAppointment } from "@/modules/appointments/service.js";

export const POST = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await noShowAppointment(ctx, params.appointmentId!));
});
