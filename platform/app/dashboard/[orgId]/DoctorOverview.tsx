import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { getBoard } from "@/modules/queue/service.js";
import { listAppointments } from "@/modules/appointments/service.js";
import {
  Badge,
  Card,
  EmptyState,
  Hero,
  HeroActions,
  HeroLabel,
  HeroMain,
  HeroSide,
  LinkButton,
  SideStat,
  StatTile,
} from "@/components/ui/index.js";
import { CalendarIcon, CheckIcon, ClockIcon, CloseIcon } from "@/components/dashboard-icons.js";

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

export async function DoctorOverview({
  ctx,
  orgId,
  doctorId,
}: {
  ctx: RequestContext;
  orgId: string;
  doctorId: string;
}) {
  const board = await getBoard(ctx, { doctorId });

  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(todayStart.getTime() + 86_400_000);
  const { data: todaysAppointments } = await listAppointments(ctx, {
    doctorId,
    from: todayStart.toISOString(),
    to: todayEnd.toISOString(),
    limit: 100,
  });

  const waiting = board.entries.filter((e) => e.state === "WAITING");
  const nextUp = waiting[0] ?? null;
  const inConsultation = board.entries.find((e) => e.state === "IN_CONSULTATION") ?? null;
  const completedToday = todaysAppointments.filter((a) => a.status === "COMPLETED").length;
  const noShowToday = todaysAppointments.filter((a) => a.status === "NO_SHOW").length;

  const nextAppointmentId = (nextUp ?? inConsultation)?.appointmentId ?? null;
  const active = inConsultation ?? nextUp;

  return (
    <div className="flex flex-col gap-7">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="font-display text-2xl font-bold text-ink">
          {new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}
        </h1>
        <LinkButton variant="secondary" href={`/dashboard/${orgId}/queue`}>
          Open queue board
        </LinkButton>
      </div>

      <Hero>
        <HeroMain>
          {active ? (
            <div>
              <HeroLabel>{inConsultation ? "Currently in consultation" : "Next patient"}</HeroLabel>
              <h2 className="relative mt-1 font-display text-xl font-bold">
                {active.patient.firstName} {active.patient.lastName}
              </h2>
              <div className="relative mt-3">
                <Badge tone="glass">Token {active.tokenNumber}</Badge>
              </div>
            </div>
          ) : (
            <div>
              <HeroLabel>Queue</HeroLabel>
              <h2 className="relative mt-1 font-display text-xl font-bold">Nobody is waiting right now</h2>
            </div>
          )}
          {inConsultation?.appointmentId ? (
            <HeroActions>
              <LinkButton variant="light" href={`/dashboard/${orgId}/appointments/${inConsultation.appointmentId}/consultation`}>
                Continue consultation
              </LinkButton>
            </HeroActions>
          ) : nextAppointmentId ? (
            <HeroActions>
              <LinkButton variant="light" href={`/dashboard/${orgId}/appointments/${nextAppointmentId}`}>
                View appointment
              </LinkButton>
            </HeroActions>
          ) : null}
        </HeroMain>
        <HeroSide>
          <SideStat value={waiting.length} label="Waiting" sub={nextUp ? `Next: ${nextUp.patient.firstName} ${nextUp.patient.lastName}` : "Nobody waiting"} />
          <SideStat label="Today's pace" sub="Avg. consult time updates as the day goes." />
        </HeroSide>
      </Hero>

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatTile icon={<ClockIcon />} tone="warn" label="Waiting" value={waiting.length} />
        <StatTile icon={<CalendarIcon />} tone="indigo" label="Today's total" value={todaysAppointments.length} />
        <StatTile icon={<CheckIcon />} tone="ok" label="Completed" value={completedToday} />
        <StatTile icon={<CloseIcon />} tone="danger" label="No-shows" value={noShowToday} />
      </div>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Today&rsquo;s schedule</h2>
        {todaysAppointments.length === 0 ? (
          <EmptyState title="No appointments today" />
        ) : (
          <div className="flex flex-col gap-2">
            {todaysAppointments.map((a) => (
              <Link key={a.id} href={`/dashboard/${orgId}/appointments/${a.id}`} className="no-underline">
                <Card className="flex flex-row items-center justify-between py-3 transition-colors hover:border-indigo">
                  <div className="flex items-center gap-3">
                    <span className="w-16 text-sm font-medium tabular-nums text-ink">
                      {new Date(a.scheduledStart).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })}
                    </span>
                    <span className="text-sm text-ink">
                      {a.patient.firstName} {a.patient.lastName}
                    </span>
                  </div>
                  <Badge tone={STATUS_TONE[a.status] ?? "neutral"}>{a.status}</Badge>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
