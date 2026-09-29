import { db } from "@/lib/db.js";
import { tenantDb } from "@/lib/tenant.js";
import type { RequestContext } from "@/lib/context.js";
import {
  computeProfileCompleteness,
  type Completeness,
} from "./completeness.js";
import { listingLifecycle, type Lifecycle } from "./lifecycle.js";

/**
 * Read-side bundle for the owner dashboard / onboarding checklist
 * (request §7/§14/§15). Read-only composition of data the tenant already
 * owns — no writes, no new state. Everything is a single round-trip so the
 * dashboard stays one query batch, and the pure calculators
 * (`computeProfileCompleteness`, `listingLifecycle`) do the judgment.
 */

export interface OrgInsights {
  org: {
    id: string;
    name: string;
    slug: string;
    orgType: string | null;
    tagline: string | null;
    about: string | null;
    logoUrl: string | null;
    coverImageUrl: string | null;
    publicPhone: string | null;
    publicEmail: string | null;
    website: string | null;
    verificationStatus: string;
    isPubliclyListed: boolean;
    isActive: boolean;
  };
  locations: Array<{
    id: string;
    name: string;
    addressLine1: string | null;
    addressLine2: string | null;
    city: string | null;
    state: string | null;
    postalCode: string | null;
    country: string | null;
    phone: string | null;
    isActive: boolean;
  }>;
  counts: {
    activeDoctors: number;
    publiclyListedDoctors: number;
    doctorsWithoutAvailability: number;
    appointmentTypes: number;
    staff: number;
  };
  doctorsWithoutAvailabilityNames: string[];
  completeness: Completeness;
  lifecycle: Lifecycle;
}

export async function getOrgInsights(ctx: RequestContext, orgId: string): Promise<OrgInsights> {
  const t = tenantDb(ctx);

  const [org, locations, activeDoctors, publiclyListedDoctors, appointmentTypes, staff, rules] =
    await Promise.all([
      t.organization.findFirstOrThrow({
        where: { id: orgId },
        select: {
          id: true,
          name: true,
          slug: true,
          orgType: true,
          tagline: true,
          about: true,
          logoUrl: true,
          coverImageUrl: true,
          publicPhone: true,
          publicEmail: true,
          website: true,
          verificationStatus: true,
          isPubliclyListed: true,
          isActive: true,
        },
      }),
      t.clinicLocation.findMany({
        where: { organizationId: orgId, isActive: true },
        orderBy: { name: "asc" },
        select: {
          id: true,
          name: true,
          addressLine1: true,
          addressLine2: true,
          city: true,
          state: true,
          postalCode: true,
          country: true,
          phone: true,
          isActive: true,
        },
      }),
      t.doctorProfile.findMany({
        where: { organizationId: orgId, isActive: true },
        select: { id: true, displayName: true },
      }),
      t.doctorProfile.count({
        where: { organizationId: orgId, isActive: true, isPubliclyListed: true },
      }),
      t.appointmentType.count({ where: { organizationId: orgId, isActive: true } }),
      t.staffProfile.count({ where: { organizationId: orgId, isActive: true } }),
      t.availabilityRule.findMany({
        where: { organizationId: orgId, isActive: true },
        select: { doctorId: true },
        distinct: ["doctorId"],
      }),
    ]);

  const doctorIdsWithRules = new Set(rules.map((r) => r.doctorId));
  const doctorsWithoutAvailability = activeDoctors.filter((d) => !doctorIdsWithRules.has(d.id));

  const completeness = computeProfileCompleteness(
    {
      name: org.name,
      orgType: org.orgType,
      tagline: org.tagline,
      about: org.about,
      publicPhone: org.publicPhone,
      publicEmail: org.publicEmail,
      website: org.website,
      logoUrl: org.logoUrl,
      coverImageUrl: org.coverImageUrl,
      locations: locations.map((l) => ({
        city: l.city,
        hasFullAddress: Boolean(l.addressLine1 && l.city),
      })),
      publiclyListedDoctorCount: publiclyListedDoctors,
      activeDoctorCount: activeDoctors.length,
      appointmentTypeCount: appointmentTypes,
      verificationStatus: org.verificationStatus,
    },
    orgId,
  );

  const lifecycle = listingLifecycle({
    verificationStatus: org.verificationStatus,
    isPubliclyListed: org.isPubliclyListed,
    isActive: org.isActive,
    orgType: org.orgType,
    tagline: org.tagline,
    about: org.about,
    publicPhone: org.publicPhone,
    publicEmail: org.publicEmail,
    activeLocationCount: locations.length,
    name: org.name,
  });

  return {
    org,
    locations,
    counts: {
      activeDoctors: activeDoctors.length,
      publiclyListedDoctors,
      doctorsWithoutAvailability: doctorsWithoutAvailability.length,
      appointmentTypes,
      staff,
    },
    doctorsWithoutAvailabilityNames: doctorsWithoutAvailability.map((d) => d.displayName),
    completeness,
    lifecycle,
  };
}

/**
 * Used by the superadmin dashboard (extension of platformStats, request §9).
 * Counts outside any tenant context — the caller (superadmin module) has
 * already asserted `isPlatformAdmin`.
 */
export async function platformWideVerificationCounts(): Promise<{
  total: number;
  active: number;
  verified: number;
  pendingVerification: number;
  rejected: number;
  publiclyListed: number;
}> {
  const [total, active, verified, pendingVerification, rejected, publiclyListed] = await Promise.all([
    db.organization.count(),
    db.organization.count({ where: { isActive: true } }),
    db.organization.count({ where: { verificationStatus: "VERIFIED" } }),
    db.organization.count({ where: { verificationStatus: "PENDING_VERIFICATION" } }),
    db.organization.count({ where: { verificationStatus: "REJECTED" } }),
    db.organization.count({ where: { isPubliclyListed: true, isActive: true } }),
  ]);
  return { total, active, verified, pendingVerification, rejected, publiclyListed };
}
