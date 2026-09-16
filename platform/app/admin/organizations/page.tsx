import Link from "next/link";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { listOrganizations } from "@/modules/superadmin/service.js";
import { Badge, Button, Card, EmptyState, Field, SectionTitle, Select, Table, td, th } from "../../dashboard/ui.js";

export const dynamic = "force-dynamic";

export default async function AdminOrganizationsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: "all" | "active" | "suspended" }>;
}) {
  const ctx = await requireSuperAdmin();
  const { q, status } = await searchParams;
  const { data: orgs } = await listOrganizations(ctx, { q, status: status ?? "all", limit: 100 });

  return (
    <div>
      <SectionTitle>Clinics ({orgs.length})</SectionTitle>
      <Card style={{ marginBottom: 20 }}>
        <form style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "flex-end" }}>
          <div style={{ flex: "1 1 240px" }}>
            <Field label="Search by name or slug" name="q" defaultValue={q} placeholder="Search…" />
          </div>
          <div style={{ flex: "0 1 180px" }}>
            <Select label="Status" name="status" defaultValue={status ?? "all"}>
              <option value="all">All</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended</option>
            </Select>
          </div>
          <div style={{ marginBottom: 12 }}>
            <Button variant="ghost">Filter</Button>
          </div>
        </form>
      </Card>

      <Card>
        {orgs.length === 0 ? (
          <EmptyState>No clinics found.</EmptyState>
        ) : (
          <Table>
            <thead>
              <tr>
                <th style={th}>Name</th>
                <th style={th}>Slug</th>
                <th style={th}>Status</th>
                <th style={th}>Members</th>
                <th style={th}>Patients</th>
                <th style={th}>Appointments</th>
                <th style={th}>Created</th>
              </tr>
            </thead>
            <tbody>
              {orgs.map((o) => (
                <tr key={o.id}>
                  <td style={td}>
                    <Link href={`/admin/organizations/${o.id}`} style={{ color: "var(--indigo)" }}>
                      {o.name}
                    </Link>
                  </td>
                  <td style={td}>{o.slug}</td>
                  <td style={td}>
                    <Badge tone={o.isActive ? "ok" : "coral"}>{o.isActive ? "Active" : "Suspended"}</Badge>
                  </td>
                  <td style={td}>{o._count.memberships}</td>
                  <td style={td}>{o._count.patients}</td>
                  <td style={td}>{o._count.appointments}</td>
                  <td style={td}>{new Date(o.createdAt).toLocaleDateString()}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>
    </div>
  );
}
