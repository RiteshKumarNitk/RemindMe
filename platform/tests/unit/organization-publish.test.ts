import { describe, expect, it } from "vitest";
import { canPublishOrganization } from "@/modules/clinics/publish.js";

const COMPLETE = {
  name: "Sunrise Family Clinic",
  orgType: "CLINIC",
  tagline: "Family medicine & pediatrics",
  about: null,
  publicPhone: "+91 98765 43210",
  publicEmail: null,
  activeLocationCount: 1,
};

describe("canPublishOrganization (PRODUCT_EVOLUTION_PLAN.md §15 Phase 3)", () => {
  it("is ready once name, type, a description, contact info, and a location are all present", () => {
    const result = canPublishOrganization(COMPLETE);
    expect(result.ready).toBe(true);
    expect(result.reasons).toEqual([]);
  });

  it("accepts `about` in place of `tagline` for the description requirement", () => {
    const result = canPublishOrganization({ ...COMPLETE, tagline: null, about: "A community clinic." });
    expect(result.ready).toBe(true);
  });

  it("accepts `publicEmail` in place of `publicPhone` for the contact requirement", () => {
    const result = canPublishOrganization({ ...COMPLETE, publicPhone: null, publicEmail: "hello@clinic.example" });
    expect(result.ready).toBe(true);
  });

  it("rejects a missing organization type", () => {
    const result = canPublishOrganization({ ...COMPLETE, orgType: null });
    expect(result.ready).toBe(false);
    expect(result.reasons).toContain("Choose an organization type.");
  });

  it("rejects when neither tagline nor about is set", () => {
    const result = canPublishOrganization({ ...COMPLETE, tagline: null, about: null });
    expect(result.ready).toBe(false);
    expect(result.reasons).toContain("Add a short description or an About section.");
  });

  it("rejects when neither public phone nor public email is set", () => {
    const result = canPublishOrganization({ ...COMPLETE, publicPhone: null, publicEmail: null });
    expect(result.ready).toBe(false);
    expect(result.reasons).toContain("Add a public phone number or email so patients can reach you.");
  });

  it("rejects zero active locations", () => {
    const result = canPublishOrganization({ ...COMPLETE, activeLocationCount: 0 });
    expect(result.ready).toBe(false);
    expect(result.reasons).toContain("Add at least one location.");
  });

  it("collects every unmet reason at once, not just the first", () => {
    const result = canPublishOrganization({
      name: "",
      orgType: null,
      tagline: null,
      about: null,
      publicPhone: null,
      publicEmail: null,
      activeLocationCount: 0,
    });
    expect(result.ready).toBe(false);
    expect(result.reasons).toHaveLength(5);
  });
});
