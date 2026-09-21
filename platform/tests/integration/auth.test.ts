import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { db, disconnect, truncateAll } from "../helpers/db.js";
import { call } from "../helpers/http.js";
import { registerAndLogin } from "../helpers/factories.js";
import { POST as registerRoute } from "../../app/api/auth/register/route.js";
import { POST as loginRoute } from "../../app/api/auth/login/route.js";
import { POST as refreshRoute } from "../../app/api/auth/refresh/route.js";
import { POST as logoutAllRoute } from "../../app/api/auth/logout-all/route.js";
import { GET as meRoute } from "../../app/api/me/route.js";

beforeAll(truncateAll);
afterAll(disconnect);

describe("authentication (AUTHENTICATION.md R1–R11)", () => {
  it("register → login (app) → /api/me", async () => {
    const u = await registerAndLogin("auth");
    const me = await call<{ email: string; memberships: unknown[] }>(meRoute, {
      bearer: u.accessToken,
    });
    expect(me.status).toBe(200);
    expect(me.body.email).toBe(u.email);
    expect(me.body.memberships).toEqual([]);
  });

  it("register stores an argon2id hash, never plaintext", async () => {
    const email = `hash-${Date.now()}@test.local`;
    await call(registerRoute, {
      body: { email, password: "Sup3rSecret!!", fullName: "H" },
    });
    const row = await db.user.findUniqueOrThrow({ where: { email } });
    expect(row.passwordHash).toMatch(/^\$argon2id\$/);
    expect(row.passwordHash).not.toContain("Sup3rSecret");
  });

  it("wrong password and unknown email give the same generic error", async () => {
    const u = await registerAndLogin("gen");
    const wrongPw = await call(loginRoute, {
      client: "app",
      body: { email: u.email, password: "totally-wrong" },
    });
    const unknown = await call(loginRoute, {
      client: "app",
      body: { email: `nobody-${Date.now()}@test.local`, password: "whatever" },
    });
    expect(wrongPw.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect((wrongPw.body as { error: { code: string } }).error.code).toBe("INVALID_CREDENTIALS");
    expect((unknown.body as { error: { message: string } }).error.message).toBe(
      (wrongPw.body as { error: { message: string } }).error.message,
    );
  });

  it("web login sets an HttpOnly SameSite=Lax session cookie", async () => {
    const u = await registerAndLogin("web");
    const login = await call(loginRoute, {
      client: "web",
      body: { email: u.email, password: "Passw0rd!长test" },
    });
    expect(login.status).toBe(200);
    const sc = login.headers.get("set-cookie") ?? "";
    expect(sc).toMatch(/dw_session=/);
    expect(sc).toMatch(/HttpOnly/i);
    expect(sc).toMatch(/SameSite=Lax/i);
  });

  it("refresh rotates the token; reusing a rotated token burns the family", async () => {
    const u = await registerAndLogin("rot");
    const first = await call<{ refreshToken: string; accessToken: string }>(refreshRoute, {
      body: { refreshToken: u.refreshToken },
    });
    expect(first.status).toBe(200);
    expect(first.body.refreshToken).not.toBe(u.refreshToken);

    // The new token works once...
    const second = await call<{ refreshToken: string }>(refreshRoute, {
      body: { refreshToken: first.body.refreshToken },
    });
    expect(second.status).toBe(200);

    // ...reusing the now-revoked first rotation → reuse detected.
    const reuse = await call(refreshRoute, {
      body: { refreshToken: first.body.refreshToken },
    });
    expect(reuse.status).toBe(401);
    expect((reuse.body as { error: { code: string } }).error.code).toBe("REFRESH_REUSE_DETECTED");

    // And the whole family is dead — the latest token no longer works either.
    const afterBurn = await call(refreshRoute, {
      body: { refreshToken: second.body.refreshToken },
    });
    expect(afterBurn.status).toBe(401);
  });

  it("logout-all bumps tokenVersion, invalidating outstanding access tokens", async () => {
    const u = await registerAndLogin("all");
    const before = await call(meRoute, { bearer: u.accessToken });
    expect(before.status).toBe(200);

    const out = await call(logoutAllRoute, { bearer: u.accessToken });
    expect(out.status).toBe(200);

    const after = await call(meRoute, { bearer: u.accessToken });
    expect(after.status).toBe(401);
    expect((after.body as { error: { code: string } }).error.code).toBe("TOKEN_EXPIRED");
  });
});
