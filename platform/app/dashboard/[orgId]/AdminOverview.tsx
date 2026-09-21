import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { tenantDb } from "@/lib/tenant.js";
import { listAppointments } from "@/modules/appointments/service.js";
import { Badge, EmptyState, InitialsAvatar, LinkButton, StatTile } from "@/components/ui/index.js";
import { BuildingIcon, CalendarIcon, CheckIcon, ClockIcon, CloseIcon, UsersIcon } from "@/components/dashboard-icons.js";

const STATUS_TONE: Record<string, "indigo" | "ok" | "down" | "neutral"> = {
  REQUESTED: "neutral",
  CONFIRMED: "indigo",
  CHECKED_IN: "indigo",
  WAITING: "indigo",
  IN_CONSULTATION: "indigo",
  COMPLETED: "ok",
  CANCELLED: "down",
  NO_SHOW: "down",
};

export async function AdminOverview({ ctx, orgId }: { ctx: RequestContext; orgId: string }) {
  const t = tenantDb(ctx);
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(todayStart.getTime() + 86_400_000);

  const [doctors, staff, { data: todaysAppointments }, org] = await Promise.all([
    t.doctorProfile.count({ where: { organizationId: orgId, isActive: true } }),
    t.staffProfile.count({ where: { organizationId: orgId } }),
    listAppointments(ctx, { from: todayStart.toISOString(), to: todayEnd.toISOString(), limit: 200 }),
    t.organization.findFirstOrThrow({
      where: { id: orgId },
      select: { verificationStatus: true, isPubliclyListed: true },
    }),
  ]);

  const completed = todaysAppointments.filter((a) => a.status === "COMPLETED").length;
  const waiting = todaysAppointments.filter((a) => a.status === "WAITING" || a.status === "CHECKED_IN").length;
  const cancelled = todaysAppointments.filter((a) => a.status === "CANCELLED").length;
  const noShows = todaysAppointments.filter((a) => a.status === "NO_SHOW").length;
  const recent = [...todaysAppointments]
    .sort((a, b) => +new Date(a.scheduledStart) - +new Date(b.scheduledStart))
    .slice(0, 6);

  return (
    <div className="flex flex-col gap-7">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-ink">Overview</h1>
        <Badge tone={org.verificationStatus === "VERIFIED" ? "indigo" : "neutral"}>
          {org.verificationStatus === "VERIFIED" ? "Verified" : org.isPubliclyListed ? "Listed, not verified" : "Not listed"}
        </Badge>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Link href={`/dashboard/${orgId}/doctors`} className="no-underline">
          <StatTile icon={<UsersIcon />} tone="indigo" label="Doctors" value={doctors} />
        </Link>
        <Link href={`/dashboard/${orgId}/staff`} className="no-underline">
          <StatTile icon={<UsersIcon />} tone="coral" label="Staff" value={staff} />
        </Link>
        <Link href={`/dashboard/${orgId}/appointments`} className="no-underline">
          <StatTile icon={<CalendarIcon />} tone="indigo" label="Today's total" value={todaysAppointments.length} />
        </Link>
        <Link href={`/dashboard/${orgId}/queue`} className="no-underline">
          <StatTile icon={<ClockIcon />} tone="warn" label="Waiting now" value={waiting} />
        </Link>
        <Link href={`/dashboard/${orgId}/appointments`} className="no-underline">
          <StatTile icon={<CheckIcon />} tone="ok" label="Completed today" value={completed} />
        </Link>
        <Link href={`/dashboard/${orgId}/appointments`} className="no-underline">
          <StatTile icon={<CloseIcon />} tone="neutral" label="Cancelled today" value={cancelled} />
        </Link>
        <Link href={`/dashboard/${orgId}/appointments`} className="no-underline">
          <StatTile icon={<CloseIcon />} tone="danger" label="No-shows today" value={noShows} />
        </Link>
        <Link href={`/dashboard/${orgId}/profile`} className="no-underline">
          <StatTile
            icon={<BuildingIcon />}
            tone="neutral"
            label="Public profile"
            value={org.isPubliclyListed ? "Live" : "Draft"}
          />
        </Link>
      </div>

      <div className="flex flex-wrap gap-2">
        <LinkButton variant="secondary" href={`/dashboard/${orgId}/doctors`}>
          + Add doctor
        </LinkButton>
        <LinkButton variant="secondary" href={`/dashboard/${orgId}/staff`}>
          + Add staff
        </LinkButton>
        <LinkButton variant="secondary" href={`/dashboard/${orgId}/settings`}>
          + Add location
        </LinkButton>
        <LinkButton variant="secondary" href={`/dashboard/${orgId}/queue`}>
          Open queue board
        </LinkButton>
      </div>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Today&rsquo;s schedule</h2>
        {recent.length === 0 ? (
          <EmptyState title="No appointments today" />
        ) : (
          <div className="flex flex-col gap-2">
            {recent.map((a) => (
              <Link
                key={a.id}
                href={`/dashboard/${orgId}/appointments/${a.id}`}
                className="flex items-center gap-3 rounded-2xl border border-border bg-card px-4 py-2.5 no-underline transition-colors hover:border-indigo"
              >
                <InitialsAvatar name={`${a.patient.firstName} ${a.patient.lastName}`} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13px] font-semibold text-ink">
                    {a.patient.firstName} {a.patient.lastName}
                  </div>
                  <div className="truncate text-[11.5px] text-ink-muted">{a.doctor.displayName}</div>
                </div>
                <Badge tone={STATUS_TONE[a.status] ?? "neutral"}>{a.status}</Badge>
                <span className="w-14 shrink-0 text-right text-[11.5px] tabular-nums text-ink-faint">
                  {new Date(a.scheduledStart).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
                </span>
              </Link>
            ))}
          </div>
        )}
        {todaysAppointments.length > recent.length ? (
          <div className="mt-2">
            <Link href={`/dashboard/${orgId}/appointments`} className="text-sm text-indigo no-underline">
              See all {todaysAppointments.length} today →
            </Link>
          </div>
        ) : null}
      </div>
    </div>
  );
}
