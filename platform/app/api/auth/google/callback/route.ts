import { withApi } from "@/lib/http.js";
import { parseQuery, z } from "@/lib/validation.js";
import { authSuccessResponse } from "@/lib/auth/respond.js";
import { handleCallback } from "@/lib/auth/oauth-google.js";

const querySchema = z.object({ code: z.string().min(1), state: z.string().min(1) });

function cookieValue(req: Request, name: string): string | null {
  const header = req.headers.get("cookie");
  if (!header) return null;
  for (const part of header.split(";")) {
    const [k, ...v] = part.trim().split("=");
    if (k === name) return decodeURIComponent(v.join("="));
  }
  return null;
}

export const GET = withApi({ auth: "none", rateClass: "auth" }, async ({ req, ctx }) => {
  const { code, state } = parseQuery(req.url, querySchema);
  const { userId } = await handleCallback({
    code,
    state,
    stateCookieJwt: cookieValue(req, "dw_oauth"),
  });
  return authSuccessResponse(req, userId, { ip: ctx.ip, userAgent: ctx.userAgent });
});
