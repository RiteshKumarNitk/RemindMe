import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { listAuditLog } from "@/modules/audit/service.js";
import { Card, EmptyState, SectionTitle, Table, td, th } from "../../ui.js";

export const dynamic = "force-dynamic";

export default async function AuditPage({ params }: { params: Promise<{ orgId: string }> }) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);
  const { data: rows } = await listAuditLog(ctx, { limit: 100 });

  return (
    <div>
      <SectionTitle>Audit log</SectionTitle>
      <p style={{ fontSize: 13, color: "var(--ink-muted)", marginTop: -8, marginBottom: 16 }}>
        The last 100 recorded changes for this clinic.
      </p>
      <Card>
        {rows.length === 0 ? (
          <EmptyState>Nothing recorded yet.</EmptyState>
        ) : (
          <Table>
            <thead>
              <tr>
                <th style={th}>When</th>
                <th style={th}>Action</th>
                <th style={th}>Entity</th>
                <th style={th}>Actor role</th>
              </tr>
            </thead>
            <tbody>
              {rows.map((r) => (
                <tr key={r.id}>
                  <td style={td}>{new Date(r.at).toLocaleString()}</td>
                  <td style={td}>{r.action}</td>
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
