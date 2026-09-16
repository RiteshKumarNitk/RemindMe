import { requireSuperAdmin } from "@/lib/web-context.js";
import { listPlatformAuditLog } from "@/modules/superadmin/service.js";
import { Badge, Card, EmptyState, SectionTitle, Table, td, th } from "../../dashboard/ui.js";

export const dynamic = "force-dynamic";

export default async function AdminAuditPage() {
  const ctx = await requireSuperAdmin();
  const { data: rows } = await listPlatformAuditLog(ctx, { limit: 150 });

  return (
    <div>
      <SectionTitle>Platform audit log (last {rows.length})</SectionTitle>
      <Card>
        {rows.length === 0 ? (
          <EmptyState>No audit events yet.</EmptyState>
        ) : (
          <Table>
            <thead>
              <tr>
                <th style={th}>When</th>
                <th style={th}>Clinic</th>
                <th style={th}>Action</th>
                <th style={th}>Entity</th>
                <th style={th}>Actor role</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td style={td}>{new Date(r.at).toLocaleString()}</td>
                  <td style={td}>{r.organization?.name ?? "—"}</td>
                  <td style={td}>
                    <Badge tone="indigo">{r.action}</Badge>
                  </td>
                  <td style={td}>
                    {r.entityType} · {r.entityId.slice(0, 8)}
                  </td>
                  <td style={td}>{r.actorRole ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
    </div>
  );
}
