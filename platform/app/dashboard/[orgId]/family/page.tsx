import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { listMyAccess } from "@/modules/family/service.js";
import { Badge, Card, EmptyState, InitialsAvatar } from "@/components/ui/index.js";

export const dynamic = "force-dynamic";

export default async function FamilyAccessPage({ params }: { params: Promise<{ orgId: string }> }) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const { data: grants } = await listMyAccess(ctx);

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Family access</h1>
        <p className="mt-1 text-sm text-ink-muted">Records other patients have shared with you.</p>
      </div>

      {grants.length === 0 ? (
        <Card>
          <EmptyState title="No one has shared a patient record with you yet." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {grants.map((g) => (
            <Link
              key={g.id}
              href={`/dashboard/${orgId}/patients/${g.patient.id}`}
              className="flex flex-wrap items-center gap-3 rounded-2xl border border-border bg-card px-4 py-3 no-underline transition-colors hover:border-indigo"
            >
              <InitialsAvatar name={`${g.patient.firstName} ${g.patient.lastName}`} />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-ink">
                  {g.patient.firstName} {g.patient.lastName}
                </div>
                <div className="mt-1 flex flex-wrap gap-1.5">
                  {g.permissions.map((p) => (
                    <Badge key={p} tone="indigo">
                      {p.replaceAll("_", " ")}
                    </Badge>
                  ))}
                </div>
              </div>
              <span className="text-[11.5px] text-ink-faint">
                {g.expiresAt ? `Expires ${new Date(g.expiresAt).toLocaleDateString()}` : "Never expires"}
              </span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
