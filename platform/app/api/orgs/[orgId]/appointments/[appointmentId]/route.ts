import { json, withApi } from "@/lib/http.js";
import { getAppointment } from "@/modules/appointments/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await getAppointment(ctx, params.appointmentId!));
});
