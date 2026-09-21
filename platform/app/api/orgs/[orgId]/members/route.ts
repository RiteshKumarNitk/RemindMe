import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { inviteMemberSchema } from "@/modules/clinics/schema.js";
import { inviteMember, listMembers } from "@/modules/clinics/service.js";

export const GET = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ ctx }) => json({ data: await listMembers(ctx) }),
);

export const POST = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx }) => {
    const input = await parseBody(req, inviteMemberSchema);
    return json(await inviteMember(ctx, input), { status: 201 });
  },
);
