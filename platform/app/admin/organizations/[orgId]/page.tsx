import type { ReactNode } from "react";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { getOrganizationDetail } from "@/modules/superadmin/service.js";
import { Badge, Button, Card, ErrorNote, SectionTitle, table, td, th } from "../../../dashboard/ui.js";
import { setOrganizationActiveAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function AdminOrganizationDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const ctx = await requireSuperAdmin();
  const { orgId } = await params;
  const { error } = await searchParams;

  const { org, memberships } = await getOrganizationDetail(ctx, orgId);

  return (
    <div>
      <SectionTitle>{org.name}</SectionTitle>
      <ErrorNote message={error} />

      <Card style={{ marginBottom: 20, maxWidth: 560 }}>
        <Row label="Slug" value={org.slug} />
        <Row label="Timezone" value={org.timezone} />
        <Row label="Status" value={<Badge tone={org.isActive ? "ok" : "coral"}>{org.isActive ? "Active" : "Suspended"}</Badge>} />
        <Row label="Created" value={new Date(org.createdAt).toLocaleString()} />
        <Row label="Members" value={String(org._count.memberships)} />
        <Row label="Doctors" value={String(org._count.doctorProfiles)} />
        <Row label="Staff" value={String(org._count.staffProfiles)} />
        <Row label="Patients" value={String(org._count.patients)} />
        <Row label="Appointments" value={String(org._count.appointments)} />

        <form action={setOrganizationActiveAction.bind(null, orgId, !org.isActive)} style={{ marginTop: 16 }}>
          <Button variant={org.isActive ? "danger" : "primary"}>
            {org.isActive ? "Suspend this clinic" : "Reactivate this clinic"}
          </Button>
        </form>
      </Card>

      <Card style={{ maxWidth: 640 }}>
        <SectionTitle>Members</SectionTitle>
        <table style={table}>
          <thead>
            <tr>
              <th style={th}>Name</th>
              <th style={th}>Email</th>
              <th style={th}>Role</th>
              <th style={th}>Status</th>
            </tr>
          </thead>
          <tbody>
            {memberships.map((m) => (
              <tr key={m.id}>
                <td style={td}>{m.user.fullName}</td>
                <td style={td}>{m.user.email}</td>
                <td style={td}>
                  <Badge tone="indigo">{m.role}</Badge>
                </td>
                <td style={td}>{m.status}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        padding: "6px 0",
        borderBottom: "1px solid var(--border)",
        fontSize: 14,
      }}
    >
      <span style={{ color: "var(--ink-muted)" }}>{label}</span>
      <span>{value}</span>
    </div>
  );
}
