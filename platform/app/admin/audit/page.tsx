import { requireSuperAdmin } from "@/lib/web-context.js";
import { listPlatformAuditLog } from "@/modules/superadmin/service.js";
import { Badge, Card, EmptyState } from "@/components/ui/index.js";

export const dynamic = "force-dynamic";

export default async function AdminAuditPage() {
  const ctx = await requireSuperAdmin();
  const { data: rows } = await listPlatformAuditLog(ctx, { limit: 150 });

  return (
    <div className="flex flex-col gap-6">
      <h1 className="font-display text-2xl font-bold text-ink">Platform audit log (last {rows.length})</h1>

      {rows.length === 0 ? (
        <Card>
          <EmptyState title="No audit events yet." />
        </Card>
      ) : (
        <Card>
          <div className="overflow-x-auto">
            <table className="w-full min-w-165 border-collapse text-[12.5px]">
              <thead>
                <tr className="text-left text-[10.5px] font-semibold uppercase tracking-wide text-ink-faint">
                  <th className="pb-2 pr-3">When</th>
                  <th className="pb-2 pr-3">Clinic</th>
                  <th className="pb-2 pr-3">Action</th>
                  <th className="pb-2 pr-3">Entity</th>
                  <th className="pb-2">Actor role</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => (
                  <tr key={r.id} className="border-t border-border hover:bg-surface-2">
                    <td className="py-2.5 pr-3 whitespace-nowrap text-ink-muted">{new Date(r.at).toLocaleString()}</td>
                    <td className="py-2.5 pr-3 text-ink">{r.organization?.name ?? "—"}</td>
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
