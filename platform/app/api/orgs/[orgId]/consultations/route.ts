import { json, withApi } from "@/lib/http.js";
import { parseQuery } from "@/lib/validation.js";
import { listConsultationsQuerySchema } from "@/modules/medical-records/schema.js";
import { listConsultations } from "@/modules/medical-records/service.js";

export const GET = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const q = parseQuery(req.url, listConsultationsQuerySchema);
  return json(await listConsultations(ctx, q));
});
