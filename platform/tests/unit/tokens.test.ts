import { describe, expect, it } from "vitest";
import { SignJWT } from "jose";
import { signAccessToken, verifyAccessToken } from "@/lib/auth/tokens.js";
import { env } from "@/lib/env.js";
import { AppError } from "@/lib/errors.js";

describe("access tokens", () => {
  it("round-trips userId + tokenVersion", async () => {
    const t = await signAccessToken({ userId: "user-123", tokenVersion: 4 });
    const claims = await verifyAccessToken(t);
    expect(claims).toEqual({ userId: "user-123", tokenVersion: 4 });
  });

  it("rejects a token signed with the wrong secret", async () => {
    const bad = await new SignJWT({ tv: 0 })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("x")
      .setIssuer(env.JWT_ISSUER)
      .setExpirationTime("5m")
      .sign(new TextEncoder().encode("not-the-real-secret-not-the-real-secret"));
    await expect(verifyAccessToken(bad)).rejects.toBeInstanceOf(AppError);
  });

  it("maps an expired token to TOKEN_EXPIRED", async () => {
    const expired = await new SignJWT({ tv: 0 })
      .setProtectedHeader({ alg: "HS256" })
      .setSubject("x")
      .setIssuer(env.JWT_ISSUER)
      .setIssuedAt(Math.floor(Date.now() / 1000) - 100)
      .setExpirationTime(Math.floor(Date.now() / 1000) - 10)
      .sign(new TextEncoder().encode(env.JWT_ACCESS_SECRET));
    try {
      await verifyAccessToken(expired);
      expect.unreachable();
    } catch (e) {
      expect((e as AppError).code).toBe("TOKEN_EXPIRED");
    }
  });
});
