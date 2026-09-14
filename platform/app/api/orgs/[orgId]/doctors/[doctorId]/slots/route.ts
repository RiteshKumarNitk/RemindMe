import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { slotsQuerySchema } from "@/modules/availability/schema.js";
import { computeSlots } from "@/modules/availability/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const q = parseQuery(req.url, slotsQuerySchema);
  return json(await computeSlots(ctx, params.doctorId!, q.date, q.typeId));
});
