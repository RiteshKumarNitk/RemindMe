import { json, withApi } from "@/lib/http.js";
import { parseBody } from "@/lib/validation.js";
import { refreshSchema } from "@/modules/auth/schema.js";
import { accessClaimsFor } from "@/modules/auth/service.js";
import { rotateRefreshToken, signAccessToken } from "@/lib/auth/tokens.js";

export const POST = withApi({ auth: "none", rateClass: "auth" }, async ({ req, ctx }) => {
  const { refreshToken } = await parseBody(req, refreshSchema);
  const rotated = await rotateRefreshToken(refreshToken, {
    ip: ctx.ip,
    userAgent: ctx.userAgent,
  });
  const { tokenVersion } = await accessClaimsFor(rotated.userId);
  const accessToken = await signAccessToken({ userId: rotated.userId, tokenVersion });
  return json({ accessToken, refreshToken: rotated.raw, tokenType: "Bearer" });
});
