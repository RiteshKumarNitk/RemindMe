import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { listAppointments } from "@/modules/appointments/service.js";
import { Badge, Card, EmptyState, InitialsAvatar, LinkButton, StatTile } from "@/components/ui/index.js";
import { CalendarIcon, CheckIcon, ClockIcon, CloseIcon, UsersIcon } from "@/components/dashboard-icons.js";

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

export async function ReceptionOverview({ ctx, orgId }: { ctx: RequestContext; orgId: string }) {
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(todayStart.getTime() + 86_400_000);

  const { data: todaysAppointments } = await listAppointments(ctx, {
    from: todayStart.toISOString(),
    to: todayEnd.toISOString(),
    limit: 200,
  });

  const checkedIn = todaysAppointments.filter((a) => a.status === "CHECKED_IN").length;
  const waiting = todaysAppointments.filter((a) => a.status === "WAITING").length;
  const inConsultation = todaysAppointments.filter((a) => a.status === "IN_CONSULTATION").length;
  const noShows = todaysAppointments.filter((a) => a.status === "NO_SHOW").length;
  const upNext = todaysAppointments
    .filter((a) => ["REQUESTED", "CONFIRMED", "CHECKED_IN", "WAITING"].includes(a.status))
    .sort((a, b) => +new Date(a.scheduledStart) - +new Date(b.scheduledStart))
    .slice(0, 8);

  return (
    <div className="flex flex-col gap-7">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-ink">
          {new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}
        </h1>
        <div className="flex flex-wrap gap-2">
          <LinkButton variant="secondary" href={`/dashboard/${orgId}/patients`}>
            Search patient
          </LinkButton>
          <LinkButton href={`/dashboard/${orgId}/queue`}>Open queue board</LinkButton>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-5">
        <StatTile icon={<CalendarIcon />} tone="indigo" label="Today's total" value={todaysAppointments.length} />
        <StatTile icon={<CheckIcon />} tone="ok" label="Checked in" value={checkedIn} />
        <StatTile icon={<ClockIcon />} tone="warn" label="Waiting" value={waiting} />
        <StatTile icon={<UsersIcon />} tone="coral" label="In consultation" value={inConsultation} />
        <StatTile icon={<CloseIcon />} tone="danger" label="No-shows" value={noShows} />
      </div>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Up next, all doctors</h2>
        {upNext.length === 0 ? (
          <EmptyState title="Nothing left on today's schedule" />
        ) : (
          <Card className="p-2">
            {upNext.map((a) => (
              <Link
                key={a.id}
                href={`/dashboard/${orgId}/appointments/${a.id}`}
                className="flex items-center gap-3 rounded-xl px-3 py-2.5 no-underline hover:bg-surface-2"
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
          </Card>
        )}
      </div>

      <LinkButton variant="secondary" href={`/dashboard/${orgId}/appointments`} className="self-start">
        + New appointment
      </LinkButton>
    </div>
  );
}
