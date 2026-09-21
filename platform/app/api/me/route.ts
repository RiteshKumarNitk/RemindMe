import { json, withApi } from "@/lib/http.js";
import { getMe } from "@/modules/users/service.js";

export const GET = withApi({ auth: "required" }, async ({ ctx }) => {
  return json(await getMe(ctx));
});
