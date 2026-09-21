import { json, withApi } from "@/lib/http.js";
import { checkInAppointment } from "@/modules/appointments/service.js";

export const POST = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await checkInAppointment(ctx, params.appointmentId!));
});
