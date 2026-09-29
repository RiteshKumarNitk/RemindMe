import { describe, expect, it } from "vitest";
import { computeProfileCompleteness } from "@/modules/clinics/completeness.js";
import { listingLifecycle } from "@/modules/clinics/lifecycle.js";

const FULL = {
  name: "Sunrise Family Clinic",
  orgType: "CLINIC",
  tagline: "Family medicine & pediatrics",
  about: "A neighbourhood clinic.",
  publicPhone: "+91 98765 43210",
  publicEmail: "hello@clinic.example",
  website: "https://clinic.example",
  logoUrl: "https://cdn.example/logo.png",
  coverImageUrl: "https://cdn.example/cover.png",
  locations: [{ city: "Jaipur", hasFullAddress: true }],
  publiclyListedDoctorCount: 2,
  activeDoctorCount: 3,
  appointmentTypeCount: 2,
  verificationStatus: "VERIFIED",
};

describe("computeProfileCompleteness (request §14)", () => {
  it("gives a fully complete profile 100% with no missing items", () => {
    const result = computeProfileCompleteness(FULL, "org1");
    expect(result.percent).toBe(100);
    expect(result.missing).toEqual([]);
  });

  it("gives a brand-new org a low but non-zero score with concrete gaps", () => {
    const result = computeProfileCompleteness(
      {
        ...FULL,
        orgType: null,
        tagline: null,
        about: null,
        publicPhone: null,
        publicEmail: null,
        website: null,
        logoUrl: null,
        coverImageUrl: null,
        locations: [],
        publiclyListedDoctorCount: 0,
        activeDoctorCount: 0,
        appointmentTypeCount: 0,
        verificationStatus: "DRAFT",
      },
      "org1",
    );
    // Only the always-present name is done: 5/100.
    expect(result.percent).toBe(5);
    expect(result.missing.map((m) => m.key)).toEqual(
      expect.arrayContaining(["orgType", "description", "contact", "location", "doctor", "types"]),
    );
    // Every missing item carries a fix-it link.
    for (const item of result.missing) {
      expect(item.href).toMatch(/^\/dashboard\/org1\//);
    }
  });

  it("counts the publish-critical items as heavier than polish items", () => {
    const result = computeProfileCompleteness(FULL, "org1");
    const contact = result.items.find((i) => i.key === "contact")!;
    const website = result.items.find((i) => i.key === "website")!;
    expect(contact.weight).toBeGreaterThan(website.weight);
  });

  it("treats a location with only a city as partial (city yes, street no)", () => {
    const result = computeProfileCompleteness(
      { ...FULL, locations: [{ city: "Jaipur", hasFullAddress: false }] },
      "org1",
    );
    expect(result.items.find((i) => i.key === "address")!.done).toBe(true);
    expect(result.items.find((i) => i.key === "fullAddress")!.done).toBe(false);
    expect(result.percent).toBeLessThan(100);
  });
});

describe("listingLifecycle (request §15)", () => {
  const READY = {
    name: "Sunrise Family Clinic",
    orgType: "CLINIC",
    tagline: "Family medicine",
    about: null,
    publicPhone: "+91 98765 43210",
    publicEmail: null,
    activeLocationCount: 1,
  };

  it("maps verified + listed to Published", () => {
    const lc = listingLifecycle({ ...READY, verificationStatus: "VERIFIED", isPubliclyListed: true, isActive: true });
    expect(lc.code).toBe("PUBLISHED");
    expect(lc.tone).toBe("ok");
  });

  it("keeps verification and listing distinct (verified but unlisted)", () => {
    const lc = listingLifecycle({ ...READY, verificationStatus: "VERIFIED", isPubliclyListed: false, isActive: true });
    expect(lc.code).toBe("VERIFIED_UNLISTED");
  });

  it("shows Ready to publish only when the publish gate passes", () => {
    const lc = listingLifecycle({ ...READY, verificationStatus: "DRAFT", isPubliclyListed: false, isActive: true });
    expect(lc.code).toBe("READY_TO_PUBLISH");
  });

  it("shows Draft — incomplete when the publish gate fails", () => {
    const lc = listingLifecycle({
      ...READY,
      tagline: null,
      about: null,
      verificationStatus: "DRAFT",
      isPubliclyListed: false,
      isActive: true,
    });
    expect(lc.code).toBe("DRAFT");
    expect(lc.readinessReasons.length).toBeGreaterThan(0);
  });

  it("maps pending verification and rejection distinctly", () => {
    const pending = listingLifecycle({ ...READY, verificationStatus: "PENDING_VERIFICATION", isPubliclyListed: false, isActive: true });
    const rejected = listingLifecycle({ ...READY, verificationStatus: "REJECTED", isPubliclyListed: false, isActive: true });
    expect(pending.code).toBe("PENDING_VERIFICATION");
    expect(pending.tone).toBe("warn");
    expect(rejected.code).toBe("REJECTED");
    expect(rejected.tone).toBe("down");
  });

  it("suspension wins over every other state", () => {
    const lc = listingLifecycle({ ...READY, verificationStatus: "VERIFIED", isPubliclyListed: true, isActive: false });
    expect(lc.code).toBe("SUSPENDED");
  });
});
