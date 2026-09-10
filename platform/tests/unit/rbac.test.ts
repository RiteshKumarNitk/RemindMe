import { describe, expect, it } from "vitest";
import {
  assertCanEditCapabilities,
  assertRole,
  hasCapability,
} from "@/lib/rbac.js";
import { AppError } from "@/lib/errors.js";
import type { RequestContext } from "@/lib/context.js";

function ctx(over: Partial<RequestContext["org"]> = {}): RequestContext {
  return {
    userId: "u1",
    isPlatformAdmin: false,
    isGuest: false,
    requestId: "r",
    ip: null,
    userAgent: null,
    org: {
      id: "org1",
      membershipId: "m1",
      role: "CLINIC_ADMIN",
      capabilities: [],
      isActive: true,
      ...over,
    },
  };
}

describe("assertRole", () => {
  it("passes for an allowed role", () => {
    expect(() => assertRole(ctx({ role: "CLINIC_ADMIN" }), "CLINIC_ADMIN")).not.toThrow();
  });
  it("throws FORBIDDEN_ROLE otherwise", () => {
    try {
      assertRole(ctx({ role: "RECEPTIONIST" }), "CLINIC_ADMIN");
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(AppError);
      expect((e as AppError).code).toBe("FORBIDDEN_ROLE");
    }
  });
  it("throws when the clinic is suspended", () => {
    expect(() => assertRole(ctx({ isActive: false }), "CLINIC_ADMIN")).toThrow(AppError);
  });
});

describe("hasCapability", () => {
  it("reflects membership capabilities", () => {
    expect(hasCapability(ctx({ capabilities: ["CLINICAL_RECORD_READ"] }), "CLINICAL_RECORD_READ")).toBe(true);
    expect(hasCapability(ctx({ capabilities: [] }), "CLINICAL_RECORD_READ")).toBe(false);
  });
});

describe("assertCanEditCapabilities — no self-grant of clinical caps", () => {
  const admin = ctx({ membershipId: "m-self", role: "CLINIC_ADMIN" });

  it("blocks granting CLINICAL_RECORD_READ to one's own membership", () => {
    try {
      assertCanEditCapabilities(admin, "m-self", ["CLINICAL_RECORD_READ"], []);
      expect.unreachable();
    } catch (e) {
      expect((e as AppError).code).toBe("CANNOT_SELF_GRANT_CAPABILITY");
    }
  });

  it("blocks revoking a clinical cap from one's own membership", () => {
    try {
      assertCanEditCapabilities(admin, "m-self", [], ["CLINICAL_RECORD_WRITE"]);
      expect.unreachable();
    } catch (e) {
      expect((e as AppError).code).toBe("CANNOT_SELF_GRANT_CAPABILITY");
    }
  });

  it("allows granting BILLING_MANAGE / DATA_EXPORT to self", () => {
    expect(() =>
      assertCanEditCapabilities(admin, "m-self", ["BILLING_MANAGE", "DATA_EXPORT"], []),
    ).not.toThrow();
  });

  it("allows granting clinical caps to a DIFFERENT membership", () => {
    expect(() =>
      assertCanEditCapabilities(admin, "m-other", ["CLINICAL_RECORD_READ"], []),
    ).not.toThrow();
  });

  it("no-ops when clinical caps are unchanged on self", () => {
    expect(() =>
      assertCanEditCapabilities(
        admin,
        "m-self",
        ["CLINICAL_RECORD_READ", "BILLING_MANAGE"],
        ["CLINICAL_RECORD_READ"],
      ),
    ).not.toThrow();
  });
});
