import { Prisma } from "@prisma/client";
import { db } from "@/lib/db.js";
import { AppError } from "@/lib/errors.js";
import { writeAudit } from "@/lib/audit.js";
import type { RequestContext } from "@/lib/context.js";
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

export async function listMyOrganizations(ctx: RequestContext) {
  const memberships = await db.membership.findMany({
    where: { userId: ctx.userId, status: "ACTIVE" },
    select: {
      role: true,
      capabilities: true,
      organization: {
        select: { id: true, name: true, slug: true, timezone: true, isActive: true },
      },
    },
    orderBy: { createdAt: "asc" },
  });
  return memberships.map((m) => ({
    ...m.organization,
    role: m.role,
    capabilities: m.capabilities,
  }));
}
