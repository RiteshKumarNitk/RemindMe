import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { createAccessGrantSchema } from "@/modules/family/schema.js";
import { createAccessGrant, listAccessGrants } from "@/modules/family/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await listAccessGrants(ctx, params.patientId!));
});

export const POST = withApi({ auth: "required" }, async ({ req, ctx, params }) => {
  const input = await parseBody(req, createAccessGrantSchema);
  return json(await createAccessGrant(ctx, params.patientId!, input), { status: 201 });
});
