import { describe, expect, it } from "vitest";
import { hashPassword, needsRehash, verifyPassword } from "@/lib/auth/password.js";

describe("password hashing (argon2id)", () => {
  it("hashes and verifies", async () => {
    const h = await hashPassword("correct horse battery staple");
    expect(h).toMatch(/^\$argon2id\$/);
    expect(await verifyPassword(h, "correct horse battery staple")).toBe(true);
    expect(await verifyPassword(h, "wrong")).toBe(false);
  });

  it("verify returns false (not throw) on a malformed hash", async () => {
    expect(await verifyPassword("not-a-hash", "x")).toBe(false);
  });

  it("needsRehash flags weaker params", () => {
    expect(needsRehash("$argon2id$v=19$m=4096,t=1,p=1$abc$def")).toBe(true);
    expect(needsRehash("garbage")).toBe(true);
  });

  it("needsRehash is false for a current-param hash", async () => {
    const h = await hashPassword("x");
    expect(needsRehash(h)).toBe(false);
  });
});
