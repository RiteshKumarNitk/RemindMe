import { json, withApi } from "@/lib/http.js";
import { parseBody, parseQuery } from "@/lib/validation.js";
import { bookSchema, listQuerySchema } from "@/modules/appointments/schema.js";
import { bookAppointment, listAppointments } from "@/modules/appointments/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, listQuerySchema);
  return json(await listAppointments(ctx, q));
});

export const POST = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, bookSchema);
  return json(await bookAppointment(ctx, input), { status: 201 });
});
