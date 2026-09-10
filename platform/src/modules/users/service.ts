import { db } from "@/lib/db.js";
import type { RequestContext } from "@/lib/context.js";

export async function getMe(ctx: RequestContext) {
  const user = await db.user.findUniqueOrThrow({
    where: { id: ctx.userId },
    select: {
      id: true,
      email: true,
      fullName: true,
      phone: true,
      avatarUrl: true,
      locale: true,
      isPlatformAdmin: true,
      isGuest: true,
      emailVerifiedAt: true,
      createdAt: true,
      memberships: {
        where: { status: "ACTIVE" },
        select: {
          id: true,
          role: true,
          capabilities: true,
          organization: { select: { id: true, name: true, slug: true, isActive: true } },
        },
      },
    },
  });

  return {
    id: user.id,
    email: user.email,
    fullName: user.fullName,
    phone: user.phone,
    avatarUrl: user.avatarUrl,
    locale: user.locale,
    isPlatformAdmin: user.isPlatformAdmin,
    isGuest: user.isGuest,
    emailVerified: user.emailVerifiedAt != null,
    createdAt: user.createdAt,
    memberships: user.memberships.map((m) => ({
      membershipId: m.id,
      orgId: m.organization.id,
      orgName: m.organization.name,
      orgSlug: m.organization.slug,
      orgActive: m.organization.isActive,
      role: m.role,
      capabilities: m.capabilities,
    })),
  };
}
