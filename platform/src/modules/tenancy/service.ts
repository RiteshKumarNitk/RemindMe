import { Prisma } from "@prisma/client";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import type { RequestContext } from "@/lib/context.js";
import { computeProfileCompleteness } from "@/modules/clinics/completeness.js";
import type { CreateOrgInput } from "./schema.js";

/**
 * Org bootstrap (MULTI_TENANCY.md "Org lifecycle"). Uses the BASE client (the
 * tenant does not exist yet) inside one transaction: Organization +
 * ClinicSettings + the creator's CLINIC_ADMIN membership are all-or-nothing.
 * A guest can never create a real org.
 */
export async function createOrganization(
  ctx: RequestContext,
  input: CreateOrgInput,
) {
  if (ctx.isGuest) {
    throw new AppError("FORBIDDEN", "Guest accounts cannot create clinics.");
  }

  try {
    const org = await db.$transaction(async (tx) => {
      const created = await tx.organization.create({
        data: {
          name: input.name.trim(),
          slug: input.slug,
          timezone: input.timezone,
          settings: { create: {} },
          memberships: {
            create: { userId: ctx.userId, role: "CLINIC_ADMIN", status: "ACTIVE" },
          },
          ...(input.location
            ? {
                locations: {
                  create: {
                    name: input.location.name,
                    city: input.location.city ?? null,
                    timezone: input.location.timezone ?? null,
                    addressLine1: input.location.addressLine1 ?? null,
                    state: input.location.state ?? null,
                    postalCode: input.location.postalCode ?? null,
                  },
                },
              }
            : {}),
        },
        select: { id: true, name: true, slug: true, timezone: true, createdAt: true },
      });
      return created;
    });

    await writeAudit(
      { ...ctx, org: { id: org.id, membershipId: "", role: "CLINIC_ADMIN", capabilities: [], isActive: true } },
      { action: "ORGANIZATION_CREATED", entityType: "Organization", entityId: org.id, after: org },
    );

    return org;
  } catch (err) {
    if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
      throw new AppError("CONFLICT", "That clinic slug is already taken.");
    }
    throw err;
  }
}

/**
 * Every clinic the user is an ACTIVE member of, enriched with the summary
 * details the post-login hub shows per card: public-profile identity
 * (type/tagline/primary city), verification + listing lifecycle state, live
 * counts (doctors, appointment types, locations), and the same honest
 * profile-completeness percentage the onboarding checklist and admin surfaces
 * use (one shared pure module — never a second, disagreeing formula).
 *
 * One round trip: filtered `_count` for types/locations, and active doctors
 * fetched as one-boolean rows so both the active count and the publicly-listed
 * count (which completeness needs) come from the same query.
 */
export async function listMyOrganizations(ctx: RequestContext) {
  const memberships = await db.membership.findMany({
    where: { userId: ctx.userId, status: "ACTIVE" },
    select: {
      role: true,
      capabilities: true,
      organization: {
        select: {
          id: true,
          name: true,
          slug: true,
          timezone: true,
          isActive: true,
          createdAt: true,
          // Public-profile details for the hub cards + completeness math.
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
          locations: {
            where: { isActive: true },
            orderBy: { createdAt: "asc" },
            select: { city: true, name: true, addressLine1: true },
          },
          doctorProfiles: {
            where: { isActive: true },
            select: { isPubliclyListed: true },
          },
          _count: {
            select: {
              appointmentTypes: { where: { isActive: true } },
              locations: { where: { isActive: true } },
            },
          },
        },
      },
    },
    orderBy: { createdAt: "asc" },
  });

  return memberships.map((m) => {
    const { locations, doctorProfiles, _count, ...org } = m.organization;
    const activeDoctorCount = doctorProfiles.length;
    const publiclyListedDoctorCount = doctorProfiles.filter((d) => d.isPubliclyListed).length;
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
        publiclyListedDoctorCount,
        activeDoctorCount,
        appointmentTypeCount: _count.appointmentTypes,
        verificationStatus: org.verificationStatus,
      },
      org.id,
    );

    return {
      ...org,
      // Primary (first active) location, collapsed for the hub card.
      location: locations[0] ?? null,
      counts: {
        doctorProfiles: activeDoctorCount,
        appointmentTypes: _count.appointmentTypes,
        locations: _count.locations,
      },
      completeness,
      role: m.role,
      capabilities: m.capabilities,
    };
  });
}
