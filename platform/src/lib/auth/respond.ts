import { json } from "../http.js";
import { accessClaimsFor } from "@/modules/auth/service.js";
import { issueRefreshToken, signAccessToken } from "./tokens.js";
import { createSession, sessionCookie } from "./session.js";

export type ClientKind = "web" | "app";

export function clientKind(req: Request): ClientKind {
  return req.headers.get("x-client") === "app" ? "app" : "web";
}

/**
 * Shape a successful auth response for the caller's client kind:
 *  - app → `{ accessToken, refreshToken, expiresIn }` in the body
 *  - web → an HttpOnly session cookie + a minimal body
 */
export async function authSuccessResponse(
  req: Request,
  userId: string,
  meta: { ip: string | null; userAgent: string | null },
  status = 200,
): Promise<Response> {
  if (clientKind(req) === "app") {
    const { tokenVersion } = await accessClaimsFor(userId);
    const accessToken = await signAccessToken({ userId, tokenVersion });
    const refresh = await issueRefreshToken(userId, meta);
    return json(
      {
        accessToken,
        refreshToken: refresh.raw,
        tokenType: "Bearer",
      },
      { status },
    );
  }
  const s = await createSession(userId, meta);
  return json(
    { ok: true },
    { status, headers: { "Set-Cookie": sessionCookie(s.raw, s.expiresAt) } },
  );
}
