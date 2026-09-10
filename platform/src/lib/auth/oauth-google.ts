import { createHash, randomBytes } from "node:crypto";
import { SignJWT, createRemoteJWKSet, jwtVerify } from "jose";
import { db } from "../db.js";
import { env, googleOAuthConfigured } from "../env.js";
import { AppError } from "../errors.js";

/**
 * Google OAuth (AUTHENTICATION.md R8/R9) — authorization-code + PKCE.
 * Inert unless GOOGLE_CLIENT_ID/SECRET are set. The user-facing flow is
 * exercised end-to-end in Phase 4 (web) with real credentials.
 */
const GOOGLE_AUTH = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN = "https://oauth2.googleapis.com/token";
const jwks = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));
const stateSecret = new TextEncoder().encode(env.AUTH_SESSION_SECRET);

function assertConfigured() {
  if (!googleOAuthConfigured) {
    throw new AppError("NOT_IMPLEMENTED", "Google sign-in is not configured.");
  }
}

export async function buildAuthUrl(): Promise<{ url: string; stateCookie: string }> {
  assertConfigured();
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  const state = randomBytes(16).toString("base64url");

  // state + verifier travel in a short-lived signed cookie (5 min).
  const stateJwt = await new SignJWT({ state, verifier })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(stateSecret);

  const params = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: env.GOOGLE_OAUTH_REDIRECT_URL,
    response_type: "code",
    scope: "openid email profile",
    code_challenge: challenge,
    code_challenge_method: "S256",
    state,
    access_type: "online",
    prompt: "select_account",
  });
  return {
    url: `${GOOGLE_AUTH}?${params}`,
    stateCookie: `dw_oauth=${stateJwt}; HttpOnly; SameSite=Lax; Path=/; Max-Age=300`,
  };
}

interface GoogleIdClaims {
  sub: string;
  email?: string;
  email_verified?: boolean;
  name?: string;
  picture?: string;
}

export async function handleCallback(input: {
  code: string;
  state: string;
  stateCookieJwt: string | null;
}): Promise<{ userId: string }> {
  assertConfigured();
  if (!input.stateCookieJwt) {
    throw new AppError("MALFORMED_REQUEST", "Missing OAuth state.");
  }
  let verifier: string;
  try {
    const { payload } = await jwtVerify(input.stateCookieJwt, stateSecret);
    if (payload.state !== input.state || typeof payload.verifier !== "string") {
      throw new Error("state mismatch");
    }
    verifier = payload.verifier;
  } catch {
    throw new AppError("MALFORMED_REQUEST", "Invalid OAuth state.");
  }

  const tokenRes = await fetch(GOOGLE_TOKEN, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      code: input.code,
      code_verifier: verifier,
      grant_type: "authorization_code",
      redirect_uri: env.GOOGLE_OAUTH_REDIRECT_URL,
    }),
  });
  if (!tokenRes.ok) {
    throw new AppError("NOT_AUTHENTICATED", "Google sign-in failed.");
  }
  const tokenJson = (await tokenRes.json()) as { id_token?: string };
  if (!tokenJson.id_token) {
    throw new AppError("NOT_AUTHENTICATED", "Google did not return an identity.");
  }
  const { payload } = await jwtVerify(tokenJson.id_token, jwks, {
    issuer: ["https://accounts.google.com", "accounts.google.com"],
    audience: env.GOOGLE_CLIENT_ID,
  });
  const claims = payload as unknown as GoogleIdClaims;

  return linkOrCreate(claims);
}

async function linkOrCreate(claims: GoogleIdClaims): Promise<{ userId: string }> {
  const existing = await db.identityAccount.findUnique({
    where: { provider_providerAccountId: { provider: "google", providerAccountId: claims.sub } },
    select: { userId: true },
  });
  if (existing) return { userId: existing.userId };

  const email = claims.email?.trim().toLowerCase();
  if (!email || claims.email_verified !== true) {
    throw new AppError("NOT_AUTHENTICATED", "Your Google email is not verified.");
  }

  const user = await db.$transaction(async (tx) => {
    const byEmail = await tx.user.findUnique({ where: { email }, select: { id: true } });
    const u =
      byEmail ??
      (await tx.user.create({
        data: {
          email,
          fullName: claims.name ?? email,
          avatarUrl: claims.picture ?? null,
          emailVerifiedAt: new Date(),
        },
        select: { id: true },
      }));
    await tx.identityAccount.create({
      data: { userId: u.id, provider: "google", providerAccountId: claims.sub },
    });
    return u;
  });
  return { userId: user.id };
}
