import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listPrescriptionsQuerySchema } from "@/modules/medical-records/schema.js";
import { listPrescriptions } from "@/modules/medical-records/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, listPrescriptionsQuerySchema);
  return json(await listPrescriptions(ctx, q));
});
