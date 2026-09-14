import { json, withApi } from "@/lib/http.js";
import { listMyAccess } from "@/modules/family/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json(await listMyAccess(ctx));
});
