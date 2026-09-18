import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { listAuditLog } from "@/modules/audit/service.js";
import { Badge, Card, EmptyState } from "@/components/ui/index.js";

export const dynamic = "force-dynamic";

export default async function AuditPage({ params }: { params: Promise<{ orgId: string }> }) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);
  const { data: rows } = await listAuditLog(ctx, { limit: 100 });

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Audit log</h1>
        <p className="mt-1 text-sm text-ink-muted">The last 100 recorded changes for this clinic.</p>
      </div>

      {rows.length === 0 ? (
        <Card>
          <EmptyState title="Nothing recorded yet." />
        </Card>
      ) : (
        <Card>
          <div className="overflow-x-auto">
            <table className="w-full min-w-140 border-collapse text-[12.5px]">
              <thead>
                <tr className="text-left text-[10.5px] font-semibold uppercase tracking-wide text-ink-faint">
                  <th className="pb-2 pr-3">When</th>
                  <th className="pb-2 pr-3">Action</th>
                  <th className="pb-2 pr-3">Entity</th>
                  <th className="pb-2">Actor role</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-t border-border hover:bg-surface-2">
                    <td className="py-2.5 pr-3 whitespace-nowrap text-ink-muted">{new Date(r.at).toLocaleString()}</td>
                    <td className="py-2.5 pr-3">
                      <Badge tone="indigo">{r.action}</Badge>
                    </td>
                    <td className="py-2.5 pr-3 font-mono text-ink-muted">
                      {r.entityType} · {r.entityId.slice(0, 8)}
                    </td>
                    <td className="py-2.5 text-ink-muted">{r.actorRole ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}
    </div>
  );
}
