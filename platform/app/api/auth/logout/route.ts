import { json, withApi } from "@/lib/http.js";
import { logoutSchema } from "@/modules/auth/schema.js";
import { clearSessionCookie, revokeSession, SESSION_COOKIE } from "@/lib/auth/session.js";
import { revokeRefreshToken } from "@/lib/auth/tokens.js";

function cookieValue(req: Request, name: string): string | null {
  const header = req.headers.get("cookie");
  if (!header) return null;
  for (const part of header.split(";")) {
    const [k, ...v] = part.trim().split("=");
    if (k === name) return decodeURIComponent(v.join("="));
  }
  return null;
}

export const POST = withApi({ auth: "optional", rateClass: "auth" }, async ({ req }) => {
  // Body may be empty; tolerate that.
  let body: { refreshToken?: string } = {};
  try {
    body = logoutSchema.parse(await req.clone().json());
  } catch {
    body = {};
  }
  if (body.refreshToken) await revokeRefreshToken(body.refreshToken);

  const sess = cookieValue(req, SESSION_COOKIE);
  if (sess) await revokeSession(sess);

  return json({ ok: true }, { headers: { "Set-Cookie": clearSessionCookie() } });
});
