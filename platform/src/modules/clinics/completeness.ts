/**
 * Profile completeness (request §14): "calculate completion from actual
 * required fields", never arbitrary percentages. Pure + DB-free, mirroring
 * `publish.ts`, so it is unit-testable and every surface (owner dashboard,
 * profile page, onboarding checklist) computes the exact same number.
 *
 * Deliberately aligned with, but broader than, `canPublishOrganization`:
 * publish readiness is the *minimum bar* for public listing (5 checks);
 * completeness is the *quality bar* the owner dashboard nudges toward
 * (logo, cover, full location addresses, doctor public profiles, types,
 * verification). An org can be 100% publish-ready while ~55% complete.
 *
 * Weights sum to 100. Every item's `href` points at the dashboard page that
 * fixes it.
 */

export interface CompletenessLocationInput {
  city: string | null;
  hasFullAddress: boolean;
}

export interface CompletenessInput {
  name: string;
  orgType: string | null;
  tagline: string | null;
  about: string | null;
  publicPhone: string | null;
  publicEmail: string | null;
  website: string | null;
  logoUrl: string | null;
  coverImageUrl: string | null;
  locations: CompletenessLocationInput[];
  publiclyListedDoctorCount: number;
  activeDoctorCount: number;
  appointmentTypeCount: number;
  verificationStatus: string;
}

export interface CompletenessItem {
  key: string;
  label: string;
  /** Dashboard route that fixes this gap. */
  href: string;
  weight: number;
  done: boolean;
}

export interface Completeness {
  percent: number;
  missing: Array<CompletenessItem>;
  /** All checklist items, done or not — drives the onboarding checklist. */
  items: Array<CompletenessItem>;
}

export function computeProfileCompleteness(
  org: CompletenessInput,
  orgId: string,
): Completeness {
  const hasDescription = Boolean(org.tagline?.trim() || org.about?.trim());
  const hasContact = Boolean(org.publicPhone?.trim() || org.publicEmail?.trim());
  const primaryLocation = org.locations[0];
  const anyFullAddress = org.locations.some((l) => l.hasFullAddress);

  // (Name comes from org creation, so it is always present in practice —
  // kept explicit anyway for honest math on odd rows.)
  const items: Array<CompletenessItem> = [
    { key: "name", label: "Organization name", href: `/dashboard/${orgId}/profile`, weight: 5, done: Boolean(org.name?.trim()) },
    { key: "orgType", label: "Organization type", href: `/dashboard/${orgId}/profile`, weight: 5, done: Boolean(org.orgType) },
    { key: "description", label: "Short description or About", href: `/dashboard/${orgId}/profile`, weight: 10, done: hasDescription },
    { key: "contact", label: "Public phone or email", href: `/dashboard/${orgId}/profile`, weight: 15, done: hasContact },
    { key: "location", label: "At least one location", href: `/dashboard/${orgId}/settings`, weight: 15, done: org.locations.length > 0 },
    { key: "address", label: "Location city / area", href: `/dashboard/${orgId}/settings`, weight: 5, done: Boolean(primaryLocation && (primaryLocation.city || primaryLocation.hasFullAddress)) },
    { key: "fullAddress", label: "Full street address on a location", href: `/dashboard/${orgId}/settings`, weight: 5, done: anyFullAddress },
    { key: "logo", label: "Logo", href: `/dashboard/${orgId}/profile`, weight: 5, done: Boolean(org.logoUrl) },
    { key: "cover", label: "Cover image", href: `/dashboard/${orgId}/profile`, weight: 5, done: Boolean(org.coverImageUrl) },
    { key: "website", label: "Website", href: `/dashboard/${orgId}/profile`, weight: 5, done: Boolean(org.website) },
    { key: "doctor", label: "At least one active doctor", href: `/dashboard/${orgId}/doctors`, weight: 10, done: org.activeDoctorCount > 0 },
    { key: "doctorPublic", label: "A doctor listed publicly", href: `/dashboard/${orgId}/doctors`, weight: 5, done: org.publiclyListedDoctorCount > 0 },
    { key: "types", label: "Appointment types configured", href: `/dashboard/${orgId}/settings`, weight: 5, done: org.appointmentTypeCount > 0 },
    { key: "verification", label: "Verified by DoseWise", href: `/dashboard/${orgId}/profile`, weight: 5, done: org.verificationStatus === "VERIFIED" },
  ];

  const total = items.reduce((sum, i) => sum + i.weight, 0);
  const done = items.reduce((sum, i) => sum + (i.done ? i.weight : 0), 0);
  const percent = total === 0 ? 0 : Math.round((done / total) * 100);

  return {
    percent,
    missing: items.filter((i) => !i.done),
    items,
  };
}

export const ORG_TYPE_LABELS: Record<string, string> = {
  HOSPITAL: "Hospital",
  CLINIC: "Clinic",
  POLYCLINIC: "Polyclinic",
  DIAGNOSTIC_CENTER: "Diagnostic centre",
  OTHER: "Healthcare provider",
};

export function orgTypeLabel(value: string | null | undefined): string {
  if (!value) return "";
  return ORG_TYPE_LABELS[value] ?? value.replace(/_/g, " ").toLowerCase();
}
