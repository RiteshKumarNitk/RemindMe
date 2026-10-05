import { withApi } from "@/lib/http.js";
import { parseBody, z } from "@/lib/validation.js";
import { authSuccessResponse } from "@/lib/auth/respond.js";
import { verifyIdToken } from "@/lib/auth/oauth-google.js";
import { accessClaimsFor } from "@/modules/auth/service.js";

const verifySchema = z.object({
  idToken: z.string().min(1),
});

export const POST = withApi({ auth: "none", rateClass: "auth" }, async ({ req, ctx }) => {
  const { idToken } = await parseBody(req, verifySchema);
  const { userId } = await verifyIdToken(idToken);
  const { tokenVersion } = await accessClaimsFor(userId);
  return authSuccessResponse(req, userId, { ip: ctx.ip, userAgent: ctx.userAgent }, 200, tokenVersion);
});
