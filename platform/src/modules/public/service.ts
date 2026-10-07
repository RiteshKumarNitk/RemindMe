import { Prisma } from "@prisma/client";
import type { z } from "zod";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import type { listPublicDoctorsQuerySchema, listPublicOrganizationsQuerySchema } from "./schema.js";

/**
 * Public healthcare discovery (PRODUCT_EVOLUTION_PLAN.md §5/§15 Phase 5) —
 * unauthenticated reads over the BASE `db` client, the same "deliberate
 * exception" pattern the superadmin module uses (ADR-001), for the opposite
 * reason: not "platform-wide access for a trusted admin" but "no tenant
 * context exists at all, because nobody is logged in."
 *
 * The safety property every function here must hold: **only rows where
 * `isActive: true` AND `isPubliclyListed: true` (and, for a doctor, the
 * SAME on its parent organization) are ever selectable, and only the
 * explicit public-field allowlists below are ever selected** — never a bare
 * `select: undefined`/spread of a full model. This is the one place in the
 * codebase where a `select` typo could leak clinical/tenant-internal data to
 * an anonymous caller, so every select block here is a named, reviewable
 * constant, not inlined per-query.
 */

const PUBLIC_ORG_SUMMARY_SELECT = {
  id: true,
  slug: true,
  name: true,
  tagline: true,
  logoUrl: true,
  orgType: true,
  verificationStatus: true,
  locations: {
    where: { isActive: true },
    select: { city: true, latitude: true, longitude: true },
    take: 5,
  },
  _count: { select: { doctorProfiles: { where: { isActive: true, isPubliclyListed: true } } } },
} satisfies Prisma.OrganizationSelect;

const PUBLIC_DOCTOR_SUMMARY_SELECT = {
  id: true,
  displayName: true,
  specialty: true,
  photoUrl: true,
  yearsOfExperience: true,
  languages: true,
  consultationFeeMinor: true,
  // Summary cards need to know whether to show a "Tokens today" affordance —
  // that's the booking mode, nothing more (public-safe: it reveals availability
  // policy, not PII).
  bookingMode: true,
} satisfies Prisma.DoctorProfileSelect;

const PUBLIC_APPOINTMENT_TYPE_SELECT = {
  id: true,
  name: true,
  durationMinutes: true,
} satisfies Prisma.AppointmentTypeSelect;

const PUBLIC_ORG_DETAIL_SELECT = {
  id: true,
  slug: true,
  name: true,
  tagline: true,
  about: true,
  logoUrl: true,
  coverImageUrl: true,
  orgType: true,
  publicPhone: true,
  publicEmail: true,
  website: true,
  verificationStatus: true,
  locations: {
    where: { isActive: true },
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
      latitude: true,
      longitude: true,
    },
  },
  doctorProfiles: {
    where: { isActive: true, isPubliclyListed: true },
    orderBy: { displayName: "asc" },
    select: PUBLIC_DOCTOR_SUMMARY_SELECT,
  },
  // Public-safe appointment types (name + duration only) so the website and
  // the patient app can offer the clinic's real booking categories instead
  // of assuming the default duration. Booking itself keeps validating the
  // chosen type server-side.
  appointmentTypes: {
    where: { isActive: true },
    orderBy: { name: "asc" },
    select: PUBLIC_APPOINTMENT_TYPE_SELECT,
  },
} satisfies Prisma.OrganizationSelect;

const PUBLIC_DOCTOR_LIST_SELECT = {
  ...PUBLIC_DOCTOR_SUMMARY_SELECT,
  organization: { select: { id: true, slug: true, name: true, logoUrl: true } },
} satisfies Prisma.DoctorProfileSelect;

const PUBLIC_DOCTOR_DETAIL_SELECT = {
  id: true,
  displayName: true,
  specialty: true,
  bio: true,
  qualifications: true,
  registrationNumber: true,
  photoUrl: true,
  yearsOfExperience: true,
  languages: true,
  consultationFeeMinor: true,
  // Token window visibility (public): booking mode + configured times are safe
  // to show (they are operational availability info, not PII). We do NOT expose
  // internal counters or the doctor's userId here.
  bookingMode: true,
  tokenOpensMinute: true,
  tokenClosesMinute: true,
  queueStartMinute: true,
  maxDailyTokens: true,
  consultationDurationMin: true,
  organization: {
    select: {
      id: true,
      slug: true,
      name: true,
      logoUrl: true,
      publicPhone: true,
      publicEmail: true,
      locations: {
        where: { isActive: true },
        select: { id: true, name: true, city: true, state: true },
      },
      appointmentTypes: {
        where: { isActive: true },
        orderBy: { name: "asc" },
        select: PUBLIC_APPOINTMENT_TYPE_SELECT,
      },
    },
  },
} satisfies Prisma.DoctorProfileSelect;

export async function listPublicOrganizations(
  q: z.infer<typeof listPublicOrganizationsQuerySchema>,
) {
  const where: Prisma.OrganizationWhereInput = {
    isActive: true,
    isPubliclyListed: true,
    ...(q.orgType ? { orgType: q.orgType } : {}),
    ...(q.q
      ? {
          OR: [
            { name: { contains: q.q, mode: "insensitive" } },
            { tagline: { contains: q.q, mode: "insensitive" } },
          ],
        }
      : {}),
    ...(q.city
      ? { locations: { some: { isActive: true, city: { equals: q.city, mode: "insensitive" } } } }
      : {}),
  };

  if (q.lat !== undefined && q.lng !== undefined) {
    return listPublicOrganizationsNear(q, where, q.lat, q.lng);
  }

  const [data, total] = await Promise.all([
    db.organization.findMany({
      where,
      select: PUBLIC_ORG_SUMMARY_SELECT,
      orderBy: { name: "asc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    db.organization.count({ where }),
  ]);

  return { data, total, page: q.page, pageSize: q.pageSize };
}

/**
 * "Clinics near me": same filters and same public-field allowlist as the
 * normal list, ordered by the great-circle distance (km) from the caller to
 * each clinic's nearest active branch. Clinics without coordinates are still
 * listed, after every clinic that has them. The caller's coordinates are only
 * used for this query — never stored or logged.
 */
async function listPublicOrganizationsNear(
  q: z.infer<typeof listPublicOrganizationsQuerySchema>,
  where: Prisma.OrganizationWhereInput,
  lat: number,
  lng: number,
) {
  const filters: Prisma.Sql[] = [Prisma.sql`o."isActive" = true`, Prisma.sql`o."isPubliclyListed" = true`];
  if (q.orgType) filters.push(Prisma.sql`o."orgType" = ${q.orgType}::"OrganizationType"`);
  if (q.q) {
    const like = `%${q.q}%`;
    filters.push(Prisma.sql`(o."name" ILIKE ${like} OR o."tagline" ILIKE ${like})`);
  }
  if (q.city) {
    filters.push(Prisma.sql`EXISTS (
      SELECT 1 FROM "ClinicLocation" c
      WHERE c."organizationId" = o."id" AND c."isActive" = true AND LOWER(c."city") = LOWER(${q.city})
    )`);
  }

  const ranked = await db.$queryRaw<Array<{ id: string; distanceKm: number | null }>>(Prisma.sql`
    SELECT o."id",
           MIN(
             6371 * 2 * ASIN(SQRT(
               POWER(SIN(RADIANS(l."latitude" - ${lat}) / 2), 2) +
               COS(RADIANS(${lat})) * COS(RADIANS(l."latitude")) *
               POWER(SIN(RADIANS(l."longitude" - ${lng}) / 2), 2)
             ))
           ) AS "distanceKm"
      FROM "Organization" o
      LEFT JOIN "ClinicLocation" l
        ON l."organizationId" = o."id" AND l."isActive" = true
       AND l."latitude" IS NOT NULL AND l."longitude" IS NOT NULL
     WHERE ${Prisma.join(filters, " AND ")}
     GROUP BY o."id", o."name"
     ORDER BY "distanceKm" ASC NULLS LAST, o."name" ASC
     LIMIT ${q.pageSize} OFFSET ${(q.page - 1) * q.pageSize}
  `);

  const ids = ranked.map((r) => r.id);
  const [rows, total] = await Promise.all([
    db.organization.findMany({ where: { id: { in: ids } }, select: PUBLIC_ORG_SUMMARY_SELECT }),
    db.organization.count({ where }),
  ]);
  const byId = new Map(rows.map((r) => [r.id, r]));
  const data = ranked
    .filter((r) => byId.has(r.id))
    .map((r) => ({
      ...byId.get(r.id)!,
      distanceKm: r.distanceKm === null ? null : Math.round(Number(r.distanceKm) * 10) / 10,
    }));

  return { data, total, page: q.page, pageSize: q.pageSize };
}

/**
 * The cities and specialties that actually exist in public discovery — for
 * the app's filter chips, so it never offers a filter that returns nothing.
 */
export async function getPublicFilters() {
  const [cities, specialties] = await Promise.all([
    db.clinicLocation.findMany({
      where: {
        isActive: true,
        city: { not: null },
        organization: { isActive: true, isPubliclyListed: true },
      },
      select: { city: true },
      distinct: ["city"],
      orderBy: { city: "asc" },
      take: 100,
    }),
    db.doctorProfile.findMany({
      where: {
        isActive: true,
        isPubliclyListed: true,
        specialty: { not: null },
        organization: { isActive: true, isPubliclyListed: true },
      },
      select: { specialty: true },
      distinct: ["specialty"],
      orderBy: { specialty: "asc" },
      take: 100,
    }),
  ]);
  return {
    cities: cities.map((c) => c.city!).filter((c) => c.trim().length > 0),
    specialties: specialties.map((s) => s.specialty!).filter((s) => s.trim().length > 0),
  };
}

export async function getPublicOrganization(slug: string) {
  const org = await db.organization.findFirst({
    where: { slug, isActive: true, isPubliclyListed: true },
    select: PUBLIC_ORG_DETAIL_SELECT,
  });
  if (!org) throw new AppError("NOT_FOUND", "Not found.");
  return org;
}

export async function listPublicDoctors(q: z.infer<typeof listPublicDoctorsQuerySchema>) {
  const where: Prisma.DoctorProfileWhereInput = {
    isActive: true,
    isPubliclyListed: true,
    organization: {
      isActive: true,
      isPubliclyListed: true,
      ...(q.organizationSlug ? { slug: q.organizationSlug } : {}),
    },
    ...(q.specialty ? { specialty: { equals: q.specialty, mode: "insensitive" } } : {}),
    ...(q.q
      ? {
          OR: [
            { displayName: { contains: q.q, mode: "insensitive" } },
            { specialty: { contains: q.q, mode: "insensitive" } },
          ],
        }
      : {}),
  };

  const [data, total] = await Promise.all([
    db.doctorProfile.findMany({
      where,
      select: PUBLIC_DOCTOR_LIST_SELECT,
      orderBy: { displayName: "asc" },
      skip: (q.page - 1) * q.pageSize,
      take: q.pageSize,
    }),
    db.doctorProfile.count({ where }),
  ]);

  return { data, total, page: q.page, pageSize: q.pageSize };
}

export async function getPublicDoctor(doctorId: string) {
  const doctor = await db.doctorProfile.findFirst({
    where: {
      id: doctorId,
      isActive: true,
      isPubliclyListed: true,
      organization: { isActive: true, isPubliclyListed: true },
    },
    select: PUBLIC_DOCTOR_DETAIL_SELECT,
  });
  if (!doctor) throw new AppError("NOT_FOUND", "Not found.");
  return doctor;
}
