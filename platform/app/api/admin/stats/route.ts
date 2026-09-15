import { json, withApi } from "@/lib/http.js";
import { platformStats } from "@/modules/superadmin/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json(await platformStats(ctx));
});
