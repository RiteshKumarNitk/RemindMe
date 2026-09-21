"use server";

import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { createSession, SESSION_COOKIE, sessionCookieOptions } from "@/lib/auth/session.js";
import { safeNextPath } from "@/lib/safe-redirect.js";
import { registerUser } from "@/modules/auth/service.js";

export async function registerAction(formData: FormData) {
  const email = String(formData.get("email") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  const fullName = String(formData.get("fullName") ?? "").trim();
  const next = safeNextPath(formData.get("next") ? String(formData.get("next")) : undefined);

  let userId: string;
  try {
    const result = await registerUser({ email, password, fullName });
    userId = result.userId;
  } catch (err) {
    const message = err instanceof AppError ? err.message : "Could not create your account.";
    redirect(`/register?error=${encodeURIComponent(message)}${next !== "/dashboard" ? `&next=${encodeURIComponent(next)}` : ""}`);
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
