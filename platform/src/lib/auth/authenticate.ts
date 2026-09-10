import { db } from "../db.js";
import { AppError } from "../errors.js";
import { SESSION_COOKIE, resolveSession } from "./session.js";
import { verifyAccessToken } from "./tokens.js";

export interface AuthedUser {
  userId: string;
  isPlatformAdmin: boolean;
  isGuest: boolean;
}

function readCookie(req: Request, name: string): string | null {
  const header = req.headers.get("cookie");
  if (!header) return null;
  for (const part of header.split(";")) {
    const [k, ...v] = part.trim().split("=");
    if (k === name) return decodeURIComponent(v.join("="));
  }
  return null;
}

/**
 * Resolve the caller from a Bearer access token (apps) or the session cookie
 * (web). Returns null when there is no credential; throws AppError for a
 * present-but-invalid credential.
 */
export async function authenticate(req: Request): Promise<AuthedUser | null> {
  const authz = req.headers.get("authorization");
  if (authz?.startsWith("Bearer ")) {
    const claims = await verifyAccessToken(authz.slice(7).trim());
    const user = await db.user.findUnique({
      where: { id: claims.userId },
      select: { id: true, isPlatformAdmin: true, isGuest: true, tokenVersion: true },
    });
    if (!user) throw new AppError("NOT_AUTHENTICATED", "Account not found.");
    if (user.tokenVersion !== claims.tokenVersion) {
      throw new AppError("TOKEN_EXPIRED", "Session was ended. Please sign in again.");
    }
    return {
      userId: user.id,
      isPlatformAdmin: user.isPlatformAdmin,
      isGuest: user.isGuest,
    };
  }

  const cookie = readCookie(req, SESSION_COOKIE);
  if (cookie) {
    const s = await resolveSession(cookie);
    if (!s) throw new AppError("NOT_AUTHENTICATED", "Session expired.");
    const user = await db.user.findUnique({
      where: { id: s.userId },
      select: { id: true, isPlatformAdmin: true, isGuest: true },
    });
    if (!user) throw new AppError("NOT_AUTHENTICATED", "Account not found.");
    return {
      userId: user.id,
      isPlatformAdmin: user.isPlatformAdmin,
      isGuest: user.isGuest,
    };
  }

  return null;
}
