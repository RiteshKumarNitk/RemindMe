"use server";

import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { createSession, SESSION_COOKIE, sessionCookieOptions } from "@/lib/auth/session.js";
import { safeNextPath } from "@/lib/safe-redirect.js";
import { loginUser } from "@/modules/auth/service.js";

export async function loginAction(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const next = safeNextPath(formData.get("next") ? String(formData.get("next")) : undefined);

  let userId: string;
  try {
    const result = await loginUser({ email, password });
    userId = result.userId;
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Sign-in failed.";
    redirect(`/login?error=${encodeURIComponent(message)}${next !== "/dashboard" ? `&next=${encodeURIComponent(next)}` : ""}`);
  }

  const h = await headers();
  const session = await createSession(userId, {
    ip: h.get("x-forwarded-for")?.split(",")[0]?.trim() ?? null,
    userAgent: h.get("user-agent"),
  });
  const jar = await cookies();
  jar.set(SESSION_COOKIE, session.raw, sessionCookieOptions(session.expiresAt));
  redirect(next);
}

export async function logoutAction() {
  const jar = await cookies();
  const token = jar.get(SESSION_COOKIE)?.value;
  if (token) {
    const { revokeSession } = await import("@/lib/auth/session.js");
    await revokeSession(token);
  }
  jar.delete(SESSION_COOKIE);
  redirect("/login");
}
