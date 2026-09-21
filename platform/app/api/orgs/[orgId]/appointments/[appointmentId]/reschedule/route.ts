import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { rescheduleSchema } from "@/modules/appointments/schema.js";
import { rescheduleAppointment } from "@/modules/appointments/service.js";

export const POST = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, rescheduleSchema);
  return json(await rescheduleAppointment(ctx, params.appointmentId!, input), {
    status: 201,
  });
});
