import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { hashPassword, needsRehash, verifyPassword } from "@/lib/auth/password.js";
import { revokeAllRefreshTokens } from "@/lib/auth/tokens.js";
import { revokeAllSessions } from "@/lib/auth/session.js";
import type { LoginInput, RegisterInput } from "./schema.js";

const normEmail = (e: string) => e.trim().toLowerCase();

export async function registerUser(input: RegisterInput): Promise<{ userId: string }> {
  const email = normEmail(input.email);
  const existing = await db.user.findUnique({ where: { email }, select: { id: true } });
  if (existing) {
    // Generic-ish: we do reveal "email taken" on register (standard trade-off),
    // but NOT on login.
    throw new AppError("EMAIL_TAKEN", "An account with that email already exists.");
  }
  const passwordHash = await hashPassword(input.password);
  const user = await db.user.create({
    data: { email, passwordHash, fullName: input.fullName.trim() },
    select: { id: true },
  });
  return { userId: user.id };
}

export async function loginUser(input: LoginInput): Promise<{ userId: string }> {
  const email = normEmail(input.email);
  const user = await db.user.findUnique({
    where: { email },
    select: { id: true, passwordHash: true },
  });
  // Constant-ish response: always run a hash verify to blunt timing signals.
  const hash =
    user?.passwordHash ??
    "$argon2id$v=19$m=19456,t=2,p=1$AAAAAAAAAAAAAAAAAAAAAA$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
  const ok = await verifyPassword(hash, input.password);
  if (!user || !user.passwordHash || !ok) {
    throw new AppError("INVALID_CREDENTIALS", "Invalid email or password.");
  }
  if (needsRehash(user.passwordHash)) {
    const fresh = await hashPassword(input.password);
    await db.user.update({ where: { id: user.id }, data: { passwordHash: fresh } });
  }
  await db.user.update({ where: { id: user.id }, data: { lastLoginAt: new Date() } });
  return { userId: user.id };
}

export async function accessClaimsFor(userId: string): Promise<{ tokenVersion: number }> {
  const u = await db.user.findUniqueOrThrow({
    where: { id: userId },
    select: { tokenVersion: true },
  });
  return { tokenVersion: u.tokenVersion };
}

/** logout-all: invalidate every session + refresh family + outstanding access token. */
export async function logoutEverywhere(userId: string): Promise<void> {
  await db.$transaction([
    db.user.update({ where: { id: userId }, data: { tokenVersion: { increment: 1 } } }),
  ]);
  await revokeAllSessions(userId);
  await revokeAllRefreshTokens(userId);
}
