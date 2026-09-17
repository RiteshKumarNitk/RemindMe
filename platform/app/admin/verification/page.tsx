import { requireSuperAdmin } from "@/lib/web-context.js";
import { listOrganizations } from "@/modules/superadmin/service.js";
import { Badge, Card, EmptyState, InitialsAvatar, LinkButton } from "@/components/ui/index.js";

export const dynamic = "force-dynamic";

export default async function AdminVerificationQueuePage() {
  const ctx = await requireSuperAdmin();
  const { data: orgs } = await listOrganizations(ctx, {
    status: "all",
    verification: "pending",
    limit: 100,
  });

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Verification queue ({orgs.length})</h1>
        <p className="mt-1 text-sm text-ink-muted">
          Clinics that have asked to be reviewed for a &ldquo;Verified&rdquo; badge on their public profile.
        </p>
      </div>

      {orgs.length === 0 ? (
        <Card>
          <EmptyState title="Nothing awaiting review." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {orgs.map((o) => (
            <Card key={o.id} className="flex flex-wrap items-center gap-3 p-4!">
              <InitialsAvatar name={o.name} />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-ink">{o.name}</div>
                <div className="truncate text-[11.5px] text-ink-muted">{o.slug}</div>
              </div>
              <Badge tone={o.isPubliclyListed ? "ok" : "neutral"}>{o.isPubliclyListed ? "Listed" : "Not listed"}</Badge>
              <span className="text-[11.5px] text-ink-faint">{o._count.memberships} members</span>
              <LinkButton variant="secondary" size="sm" href={`/admin/organizations/${o.id}`}>
                Review
              </LinkButton>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
