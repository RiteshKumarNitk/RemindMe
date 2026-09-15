import { requireSuperAdmin } from "@/lib/web-context.js";
import { platformStats } from "@/modules/superadmin/service.js";
import { Card, SectionTitle } from "../dashboard/ui.js";

export const dynamic = "force-dynamic";

export default async function AdminOverviewPage() {
  const ctx = await requireSuperAdmin();
  const stats = await platformStats(ctx);

  return (
    <div>
      <SectionTitle>Platform overview</SectionTitle>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(160px, 1fr))", gap: 14 }}>
        <StatCard label="Clinics" value={stats.organizations} />
        <StatCard label="Active clinics" value={stats.activeOrganizations} />
        <StatCard label="Suspended clinics" value={stats.organizations - stats.activeOrganizations} />
        <StatCard label="Users" value={stats.users} />
        <StatCard label="Patients" value={stats.patients} />
        <StatCard label="Appointments" value={stats.appointments} />
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <Card>
      <div style={{ fontSize: 28, fontWeight: 700 }}>{value.toLocaleString()}</div>
      <div style={{ fontSize: 12, color: "var(--ink-muted)", marginTop: 4 }}>{label}</div>
    </Card>
  );
}
