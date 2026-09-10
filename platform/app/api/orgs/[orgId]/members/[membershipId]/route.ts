import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { updateMemberSchema } from "@/modules/clinics/schema.js";
import { removeMember, updateMember } from "@/modules/clinics/service.js";

export const PATCH = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ req, ctx, params }) => {
    const input = await parseBody(req, updateMemberSchema);
    return json(await updateMember(ctx, params.membershipId!, input));
  },
);

export const DELETE = withApi(
  { auth: "required", roles: ["CLINIC_ADMIN"] },
  async ({ ctx, params }) => {
    return json(await removeMember(ctx, params.membershipId!));
  },
);
