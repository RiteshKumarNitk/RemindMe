import { randomUUID } from "node:crypto";
import { SignJWT, jwtVerify, errors as joseErrors } from "jose";
import { db } from "../db.js";
import { env } from "../env.js";
import { AppError } from "../errors.js";
import { randomToken, sha256hex } from "../crypto.js";

/**
 * Access tokens (short-lived JWT) + rotating refresh tokens with reuse
 * detection (AUTHENTICATION.md R2–R5).
 */
const accessSecret = new TextEncoder().encode(env.JWT_ACCESS_SECRET);

export interface AccessClaims {
  userId: string;
  tokenVersion: number;
}

export async function signAccessToken(claims: AccessClaims): Promise<string> {
  return new SignJWT({ tv: claims.tokenVersion })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.userId)
    .setIssuer(env.JWT_ISSUER)
    .setIssuedAt()
    .setExpirationTime(`${env.JWT_ACCESS_TTL}s`)
    .sign(accessSecret);
}

export async function verifyAccessToken(token: string): Promise<AccessClaims> {
  try {
    const { payload } = await jwtVerify(token, accessSecret, {
      issuer: env.JWT_ISSUER,
    });
    if (!payload.sub || typeof payload.tv !== "number") {
      throw new AppError("NOT_AUTHENTICATED", "Malformed access token.");
    }
    return { userId: payload.sub, tokenVersion: payload.tv };
  } catch (err) {
    if (err instanceof joseErrors.JWTExpired) {
      throw new AppError("TOKEN_EXPIRED", "Access token has expired.");
    }
    if (err instanceof AppError) throw err;
    throw new AppError("NOT_AUTHENTICATED", "Invalid access token.");
  }
}

const refreshTtlMs = env.JWT_REFRESH_TTL * 1000;

export async function issueRefreshToken(
  userId: string,
  meta: { familyId?: string; ip: string | null; userAgent: string | null },
): Promise<{ raw: string; expiresAt: Date }> {
  const raw = randomToken(32);
  const expiresAt = new Date(Date.now() + refreshTtlMs);
  await db.refreshToken.create({
    data: {
      userId,
      hashedToken: sha256hex(raw),
      familyId: meta.familyId ?? randomUUID(),
      expiresAt,
      ip: meta.ip,
      userAgent: meta.userAgent,
    },
  });
  return { raw, expiresAt };
}

/**
 * Rotate: revoke the presented token, issue a fresh one in the same family.
 * Presenting an already-revoked token = theft → revoke the whole family.
 */
export async function rotateRefreshToken(
  raw: string,
  meta: { ip: string | null; userAgent: string | null },
): Promise<{ userId: string; raw: string; expiresAt: Date }> {
  const hashed = sha256hex(raw);
  const row = await db.refreshToken.findUnique({ where: { hashedToken: hashed } });
  if (!row) {
    throw new AppError("NOT_AUTHENTICATED", "Unknown refresh token.");
  }
  if (row.revokedAt) {
    // Reuse of a revoked token — burn the family.
    await db.refreshToken.updateMany({
      where: { familyId: row.familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    throw new AppError(
      "REFRESH_REUSE_DETECTED",
      "This session has been revoked for your security. Please sign in again.",
    );
  }
  if (row.expiresAt.getTime() <= Date.now()) {
    throw new AppError("NOT_AUTHENTICATED", "Refresh token has expired.");
  }

  const next = randomToken(32);
  const expiresAt = new Date(Date.now() + refreshTtlMs);
  await db.$transaction(async (tx) => {
    const created = await tx.refreshToken.create({
      data: {
        userId: row.userId,
        hashedToken: sha256hex(next),
        familyId: row.familyId,
        expiresAt,
        ip: meta.ip,
        userAgent: meta.userAgent,
      },
    });
    await tx.refreshToken.update({
      where: { id: row.id },
      data: { revokedAt: new Date(), replacedById: created.id },
    });
  });
  return { userId: row.userId, raw: next, expiresAt };
}

export async function revokeRefreshToken(raw: string): Promise<void> {
  await db.refreshToken.updateMany({
    where: { hashedToken: sha256hex(raw), revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function revokeAllRefreshTokens(userId: string): Promise<void> {
  await db.refreshToken.updateMany({
    where: { userId, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}
