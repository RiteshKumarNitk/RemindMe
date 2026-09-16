import type { Prisma } from "@prisma/client";
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
  locations: { where: { isActive: true }, select: { city: true }, take: 5 },
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
} satisfies Prisma.DoctorProfileSelect;

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
    },
  },
  doctorProfiles: {
    where: { isActive: true, isPubliclyListed: true },
    orderBy: { displayName: "asc" },
    select: PUBLIC_DOCTOR_SUMMARY_SELECT,
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
