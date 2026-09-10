import { describe, expect, it } from "vitest";
import { AppError, toEnvelope } from "@/lib/errors.js";

describe("AppError", () => {
  it("maps codes to HTTP status", () => {
    expect(new AppError("NOT_FOUND", "x").status).toBe(404);
    expect(new AppError("VALIDATION_FAILED", "x").status).toBe(422);
    expect(new AppError("CANNOT_SELF_GRANT_CAPABILITY", "x").status).toBe(403);
    expect(new AppError("APPOINTMENT_SLOT_TAKEN", "x").status).toBe(409);
    expect(new AppError("RATE_LIMITED", "x").status).toBe(429);
    expect(new AppError("INTERNAL", "x").status).toBe(500);
    expect(new AppError("NOT_IMPLEMENTED", "x").status).toBe(501);
  });

  it("envelope omits details when absent", () => {
    expect(toEnvelope(new AppError("NOT_FOUND", "nope"))).toEqual({
      error: { code: "NOT_FOUND", message: "nope" },
    });
  });

  it("envelope includes details when present", () => {
    const env = toEnvelope(new AppError("VALIDATION_FAILED", "bad", { issues: [] }));
    expect(env.error.details).toEqual({ issues: [] });
  });
});
