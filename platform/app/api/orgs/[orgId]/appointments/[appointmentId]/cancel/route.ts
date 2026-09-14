import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { cancelSchema } from "@/modules/appointments/schema.js";
import { cancelAppointment } from "@/modules/appointments/service.js";

export const POST = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, cancelSchema);
  return json(await cancelAppointment(ctx, params.appointmentId!, input));
});
