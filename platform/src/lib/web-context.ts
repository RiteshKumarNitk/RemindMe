import { randomUUID } from "node:crypto";
import { cookies, headers } from "next/headers";
import { redirect, notFound } from "next/navigation";
import { db } from "./db.js";
import { SESSION_COOKIE, resolveSession } from "./auth/session.js";
import { resolveOrgContext } from "./org-context.js";
import type { RequestContext } from "./context.js";

/**
 * Server-side auth for the web app (Server Components + Server Actions).
 * Mirrors `withApi()`'s guarantees (SYSTEM_ARCHITECTURE.md: the web app and
 * the API share one auth/tenant model) without a self-HTTP round trip —
 * Server Components call the same module services directly.
 */

async function currentUserId(): Promise<string | null> {
  const jar = await cookies();
  const token = jar.get(SESSION_COOKIE)?.value;
  if (!token) return null;
  const session = await resolveSession(token);
  return session?.userId ?? null;
}

async function baseCtx(userId: string): Promise<RequestContext> {
  const h = await headers();
  return {
    userId,
    isPlatformAdmin: false, // re-checked below if needed
    isGuest: false,
    requestId: randomUUID(),
    ip: h.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null,
    userAgent: h.get("user-agent"),
  };
}

/** Requires a signed-in user; redirects to /login otherwise. */
export async function requireWebUser(): Promise<RequestContext> {
  const userId = await currentUserId();
  if (!userId) redirect("/login");
  const user = await db.user.findUnique({
    where: { id: userId },
    select: { isPlatformAdmin: true, isGuest: true },
  });
  if (!user) redirect("/login");
  const ctx = await baseCtx(userId);
  ctx.isPlatformAdmin = user.isPlatformAdmin;
  ctx.isGuest = user.isGuest;
  return ctx;
}

/** Signed-in user without redirecting (for the public marketing/login pages). */
export async function optionalWebUser(): Promise<RequestContext | null> {
  const userId = await currentUserId();
  if (!userId) return null;
  return baseCtx(userId);
}

/**
 * Requires a signed-in user AND an ACTIVE membership in `orgId` — the exact
 * guarantee `withApi` gives the API. No membership ⇒ 404 (never a leak).
 */
export async function requireOrgContext(orgId: string): Promise<RequestContext> {
  const ctx = await requireWebUser();
  const org = await resolveOrgContext(ctx.userId, orgId);
  if (!org) notFound();
  ctx.org = org;
  return ctx;
}

/**
 * Requires a signed-in `User.isPlatformAdmin` — the SUPER_ADMIN surface
 * (MEDICAL_DATA_SECURITY.md "SUPER_ADMIN — no routine clinical access"):
 * platform/tenant operations only, no membership in any clinic, no clinical
 * data access. A non-admin gets 404, not 403 — same "don't confirm this
 * surface exists" posture as cross-tenant lookups elsewhere.
 */
export async function requireSuperAdmin(): Promise<RequestContext> {
  const ctx = await requireWebUser();
  if (!ctx.isPlatformAdmin) notFound();
  return ctx;
}
