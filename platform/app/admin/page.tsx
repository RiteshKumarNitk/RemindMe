import { requireSuperAdmin } from "@/lib/web-context.js";
import { platformStats } from "@/modules/superadmin/service.js";
import { StatTile } from "@/components/ui/index.js";
import { BuildingIcon, CalendarIcon, CheckIcon, CloseIcon, UsersIcon } from "@/components/dashboard-icons.js";

export const dynamic = "force-dynamic";

export default async function AdminOverviewPage() {
  const ctx = await requireSuperAdmin();
  const stats = await platformStats(ctx);

  return (
    <div className="flex flex-col gap-7">
      <h1 className="font-display text-2xl font-bold text-ink">Platform overview</h1>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
        <StatTile icon={<BuildingIcon />} tone="indigo" label="Clinics" value={stats.organizations.toLocaleString()} />
        <StatTile icon={<CheckIcon />} tone="ok" label="Active clinics" value={stats.activeOrganizations.toLocaleString()} />
        <StatTile
          icon={<CloseIcon />}
          tone="danger"
          label="Suspended clinics"
          value={(stats.organizations - stats.activeOrganizations).toLocaleString()}
        />
        <StatTile icon={<UsersIcon />} tone="coral" label="Users" value={stats.users.toLocaleString()} />
        <StatTile icon={<UsersIcon />} tone="warn" label="Patients" value={stats.patients.toLocaleString()} />
        <StatTile icon={<CalendarIcon />} tone="neutral" label="Appointments" value={stats.appointments.toLocaleString()} />
      </div>
    </div>
  );
}
