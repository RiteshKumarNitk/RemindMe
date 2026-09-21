import { withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { authSuccessResponse } from "@/lib/auth/respond.js";
import { loginSchema } from "@/modules/auth/schema.js";
import { loginUser } from "@/modules/auth/service.js";

export const POST = withApi({ auth: "none", rateClass: "auth" }, async ({ req, ctx }) => {
  const input = await parseBody(req, loginSchema);
  const { userId, tokenVersion } = await loginUser(input);
  return authSuccessResponse(req, userId, { ip: ctx.ip, userAgent: ctx.userAgent }, 200, tokenVersion);
});
