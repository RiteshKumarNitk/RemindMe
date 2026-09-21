import { db } from "../db.js";
import { env } from "../env.js";
import { randomToken, sha256hex } from "../crypto.js";

/**
 * Web cookie sessions (AUTHENTICATION.md "Web sessions"). The cookie carries
 * the raw token; only `sha256(token)` is stored. Sliding renewal past the
 * halfway mark. Server-side revocation.
 */
export const SESSION_COOKIE = "dw_session";
const SESSION_TTL_MS = 1000 * 60 * 60 * 24 * 14; // 14 days

export async function createSession(
  userId: string,
  meta: { ip: string | null; userAgent: string | null },
): Promise<{ raw: string; expiresAt: Date }> {
  const raw = randomToken(32);
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS);
  await db.session.create({
    data: {
      userId,
      hashedSessionToken: sha256hex(raw),
      expiresAt,
      ip: meta.ip,
      userAgent: meta.userAgent,
    },
  });
  return { raw, expiresAt };
}

export async function resolveSession(
  raw: string,
): Promise<{ userId: string } | null> {
  const row = await db.session.findUnique({
    where: { hashedSessionToken: sha256hex(raw) },
  });
  if (!row) return null;
  const now = Date.now();
  if (row.expiresAt.getTime() <= now) {
    await db.session.delete({ where: { id: row.id } }).catch(() => {});
    return null;
  }
  // Sliding renewal.
  const age = now - row.createdAt.getTime();
  if (age > SESSION_TTL_MS / 2) {
    await db.session.update({
      where: { id: row.id },
      data: { expiresAt: new Date(now + SESSION_TTL_MS) },
    });
  }
  return { userId: row.userId };
}

export async function revokeSession(raw: string): Promise<void> {
  await db.session
    .delete({ where: { hashedSessionToken: sha256hex(raw) } })
    .catch(() => {});
}

export async function revokeAllSessions(userId: string): Promise<void> {
  await db.session.deleteMany({ where: { userId } });
}

/** Options form for `next/headers` cookies().set() (web app Server Actions). */
export function sessionCookieOptions(expiresAt: Date) {
  return {
    httpOnly: true,
    sameSite: "lax" as const,
    path: "/",
    secure: env.NODE_ENV === "production",
    expires: expiresAt,
  };
}

export function sessionCookie(raw: string, expiresAt: Date): string {
  const secure = env.NODE_ENV === "production" ? " Secure;" : "";
  return (
    `${SESSION_COOKIE}=${raw}; HttpOnly;${secure} SameSite=Lax; Path=/; ` +
    `Expires=${expiresAt.toUTCString()}`
  );
}

export function clearSessionCookie(): string {
  return `${SESSION_COOKIE}=; HttpOnly; SameSite=Lax; Path=/; Max-Age=0`;
}
