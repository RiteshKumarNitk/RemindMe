import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { tenantDb } from "@/lib/tenant.js";
import { listAppointments } from "@/modules/appointments/service.js";
import { Badge, Card, EmptyState, LinkButton } from "@/components/ui/index.js";

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
    <div className="flex max-w-3xl flex-col gap-6">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-2xl font-semibold text-ink">Overview</h1>
        <Badge tone={org.verificationStatus === "VERIFIED" ? "indigo" : "neutral"}>
          {org.verificationStatus === "VERIFIED" ? "Verified" : org.isPubliclyListed ? "Listed, not verified" : "Not listed"}
        </Badge>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="Doctors" value={doctors} href={`/dashboard/${orgId}/doctors`} />
        <StatCard label="Staff" value={staff} href={`/dashboard/${orgId}/staff`} />
        <StatCard label="Today's total" value={todaysAppointments.length} href={`/dashboard/${orgId}/appointments`} />
        <StatCard label="Waiting now" value={waiting} href={`/dashboard/${orgId}/queue`} />
        <StatCard label="Completed today" value={completed} href={`/dashboard/${orgId}/appointments`} />
        <StatCard label="Cancelled today" value={cancelled} href={`/dashboard/${orgId}/appointments`} />
        <StatCard label="No-shows today" value={noShows} href={`/dashboard/${orgId}/appointments`} />
        <StatCard label="Public profile" value={org.isPubliclyListed ? 1 : 0} href={`/dashboard/${orgId}/profile`} suffix={org.isPubliclyListed ? "Live" : "Draft"} />
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
        <h2 className="mb-3 text-lg font-semibold text-ink">Today&rsquo;s schedule</h2>
        {recent.length === 0 ? (
          <EmptyState title="No appointments today" />
        ) : (
          <div className="flex flex-col gap-2">
            {recent.map((a) => (
              <Link key={a.id} href={`/dashboard/${orgId}/appointments/${a.id}`} className="no-underline">
                <Card className="flex flex-row items-center justify-between py-3">
                  <div className="flex items-center gap-3">
                    <span className="w-16 text-sm font-medium text-ink">
                      {new Date(a.scheduledStart).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
                    </span>
                    <span className="text-sm text-ink">
                      {a.patient.firstName} {a.patient.lastName}
                    </span>
                    <span className="text-sm text-ink-muted">{a.doctor.displayName}</span>
                  </div>
                  <Badge tone={STATUS_TONE[a.status] ?? "neutral"}>{a.status}</Badge>
                </Card>
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

function StatCard({ label, value, href, suffix }: { label: string; value: number; href: string; suffix?: string }) {
  return (
    <Link href={href} className="no-underline">
      <Card className="py-4 text-center transition-colors hover:border-indigo">
        <div className="text-2xl font-bold text-ink">{suffix ?? value}</div>
        <div className="mt-1 text-xs text-ink-muted">{label}</div>
      </Card>
    </Link>
  );
}
