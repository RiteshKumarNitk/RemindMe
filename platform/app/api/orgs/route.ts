import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { createOrgSchema } from "@/modules/tenancy/schema.js";
import { createOrganization, listMyOrganizations } from "@/modules/tenancy/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json({ data: await listMyOrganizations(ctx) });
});

export const POST = withApi({ auth: "required" }, async ({ req, ctx }) => {
  const input = await parseBody(req, createOrgSchema);
  const org = await createOrganization(ctx, input);
  return json(org, { status: 201 });
});
