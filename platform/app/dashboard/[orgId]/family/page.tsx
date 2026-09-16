import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { listMyAccess } from "@/modules/family/service.js";
import { Badge, Card, EmptyState, SectionTitle, Table, td, th } from "../../ui.js";

export const dynamic = "force-dynamic";

export default async function FamilyAccessPage({ params }: { params: Promise<{ orgId: string }> }) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const { data: grants } = await listMyAccess(ctx);

  return (
    <div>
      <SectionTitle>Family access</SectionTitle>
      <Card>
        {grants.length === 0 ? (
          <EmptyState>No one has shared a patient record with you yet.</EmptyState>
        ) : (
          <Table>
            <thead>
              <tr>
                <th style={th}>Patient</th>
                <th style={th}>Permissions</th>
                <th style={th}>Expires</th>
              </tr>
            </thead>
            <tbody>
              {grants.map((g) => (
                <tr key={g.id}>
                  <td style={td}>
                    <Link href={`/dashboard/${orgId}/patients/${g.patient.id}`} style={{ color: "var(--indigo)" }}>
                      {g.patient.firstName} {g.patient.lastName}
                    </Link>
                  </td>
                  <td style={td}>
                    {g.permissions.map((p) => (
                      <span key={p} style={{ marginRight: 4, display: "inline-block" }}>
                        <Badge tone="indigo">{p.replaceAll("_", " ")}</Badge>
                      </span>
                    ))}
                  </td>
                  <td style={td}>{g.expiresAt ? new Date(g.expiresAt).toLocaleDateString() : "Never"}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
    </div>
  );
}
