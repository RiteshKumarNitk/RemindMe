import { beforeEach, describe, expect, it } from "vitest";
import { __resetRateLimiter, checkRateLimit } from "@/lib/rate-limit.js";
import { AppError } from "@/lib/errors.js";
import { env } from "@/lib/env.js";

describe("checkRateLimit", () => {
  beforeEach(() => __resetRateLimiter());

  it("allows up to the limit then throws RATE_LIMITED", () => {
    const limit = env.RATE_LIMIT_AUTH_PER_MIN;
    for (let i = 0; i < limit; i++) {
      expect(() => checkRateLimit("1.2.3.4", "auth")).not.toThrow();
    }
    try {
      checkRateLimit("1.2.3.4", "auth");
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(AppError);
      expect((e as AppError).code).toBe("RATE_LIMITED");
      expect((e as AppError).details).toMatchObject({ retryAfter: expect.any(Number) });
    }
  });

  it("keeps separate buckets per identity + class", () => {
    for (let i = 0; i < env.RATE_LIMIT_AUTH_PER_MIN; i++) checkRateLimit("a", "auth");
    expect(() => checkRateLimit("b", "auth")).not.toThrow();
    expect(() => checkRateLimit("a", "default")).not.toThrow();
  });
});
