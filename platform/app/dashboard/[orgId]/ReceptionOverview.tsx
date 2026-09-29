import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { listAppointments } from "@/modules/appointments/service.js";
import {
  Badge,
  Button,
  Card,
  EmptyState,
  InitialsAvatar,
  LinkButton,
  StatTile,
  statusLabel,
  statusTone,
} from "@/components/ui/index.js";
import { ConfirmSubmit } from "@/components/confirm-submit.js";
import { checkInAppointmentAction } from "./appointments/actions.js";
import { CalendarIcon, CheckIcon, ClockIcon, CloseIcon, UsersIcon } from "@/components/dashboard-icons.js";

/**
 * Reception dashboard (request §6): "what does the front desk need to handle
 * now?" — today's operational counts, then the live "up next" list with the
 * queue token inline and one-tap check-in (ConfirmSubmit on the
 * state-changing action). The queue state machine itself is untouched; the
 * inline form calls the exact same `checkInAppointment` service the
 * appointments page uses.
 */
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
  const completed = todaysAppointments.filter((a) => a.status === "COMPLETED").length;
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

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-6">
        <StatTile icon={<CalendarIcon />} tone="indigo" label="Today's total" value={todaysAppointments.length} />
        <StatTile icon={<UsersIcon />} tone="coral" label="In consultation" value={inConsultation} />
        <StatTile icon={<ClockIcon />} tone="warn" label="Waiting" value={waiting} />
        <StatTile icon={<CheckIcon />} tone="ok" label="Checked in" value={checkedIn} />
        <StatTile icon={<CheckIcon />} tone="ok" label="Completed" value={completed} />
        <StatTile icon={<CloseIcon />} tone="danger" label="No-shows" value={noShows} />
      </div>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Up next, all doctors</h2>
        {upNext.length === 0 ? (
          <EmptyState
            title="Nothing left on today's schedule"
            action={
              <LinkButton href={`/dashboard/${orgId}/appointments`}>Book an appointment</LinkButton>
            }
          />
        ) : (
          <Card className="p-2">
            {upNext.map((a) => (
              <div
                key={a.id}
                className="flex flex-wrap items-center gap-3 rounded-xl px-3 py-2.5 hover:bg-surface-2"
              >
                <Link
                  href={`/dashboard/${orgId}/appointments/${a.id}`}
                  className="flex min-w-0 flex-1 items-center gap-3 no-underline"
                >
                  <InitialsAvatar name={`${a.patient.firstName} ${a.patient.lastName}`} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[13px] font-semibold text-ink">
                      {a.patient.firstName} {a.patient.lastName}
                      {a.queueEntry ? (
                        <span className="ml-2 align-middle font-mono text-[11px] text-ink-faint">
                          #{a.queueEntry.tokenNumber}
                        </span>
                      ) : null}
                    </div>
                    <div className="truncate text-[11.5px] text-ink-muted">
                      {a.doctor.displayName}
                      {a.location ? ` · ${a.location.name}` : ""}
                    </div>
                  </div>
                  <Badge tone={statusTone(a.status)}>{statusLabel(a.status)}</Badge>
                </Link>
                <div className="flex items-center gap-2">
                  <span className="w-14 text-right text-[11.5px] tabular-nums text-ink-faint">
                    {new Date(a.scheduledStart).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
                  </span>
                  {a.status === "CONFIRMED" ? (
                    <form action={checkInAppointmentAction.bind(null, orgId, a.id)}>
                      <ConfirmSubmit
                        label="Check in"
                        variant="secondary"
                        size="sm"
                        confirmTitle={`Check in ${a.patient.firstName} ${a.patient.lastName}?`}
                        confirmMessage="They'll receive a queue token and join the waiting list."
                      />
                    </form>
                  ) : null}
                </div>
              </div>
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
