import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { putRulesSchema } from "@/modules/availability/schema.js";
import { getRules, replaceRules } from "@/modules/availability/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json({ data: await getRules(ctx, params.doctorId!) });
});

export const PUT = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, putRulesSchema);
  return json({ data: await replaceRules(ctx, params.doctorId!, input) });
});
