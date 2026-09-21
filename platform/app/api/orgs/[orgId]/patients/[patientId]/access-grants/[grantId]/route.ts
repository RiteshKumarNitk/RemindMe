import { json, withApi } from "@/lib/http.js";
import { revokeAccessGrant } from "@/modules/family/service.js";

export const DELETE = withApi({ auth: "required" }, async ({ ctx, params }) => {
  return json(await revokeAccessGrant(ctx, params.patientId!, params.grantId!));
});
