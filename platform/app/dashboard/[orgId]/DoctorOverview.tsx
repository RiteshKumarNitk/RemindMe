import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { getBoard } from "@/modules/queue/service.js";
import { listAppointments } from "@/modules/appointments/service.js";
import { Badge, Button, Card, CardSubtitle, CardTitle, EmptyState } from "@/components/ui/index.js";

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

  return (
    <div className="flex max-w-3xl flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-ink">
          {new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}
        </h1>
        <Link href={`/dashboard/${orgId}/queue`}>
          <Button variant="secondary">Open queue board</Button>
        </Link>
      </div>

      {inConsultation ? (
        <Card>
          <CardSubtitle>Currently in consultation</CardSubtitle>
          <CardTitle className="mt-1 text-lg">
            {inConsultation.patient.firstName} {inConsultation.patient.lastName}
          </CardTitle>
          <div className="mt-2">
            <Badge tone="indigo">Token {inConsultation.tokenNumber}</Badge>
          </div>
          {inConsultation.appointmentId ? (
            <div className="mt-4">
              <Link href={`/dashboard/${orgId}/appointments/${inConsultation.appointmentId}/consultation`}>
                <Button>Continue consultation</Button>
              </Link>
            </div>
          ) : null}
        </Card>
      ) : nextUp ? (
        <Card>
          <CardSubtitle>Next patient</CardSubtitle>
          <CardTitle className="mt-1 text-lg">
            {nextUp.patient.firstName} {nextUp.patient.lastName}
          </CardTitle>
          <div className="mt-2">
            <Badge tone="indigo">Token {nextUp.tokenNumber}</Badge>
          </div>
          {nextAppointmentId ? (
            <div className="mt-4">
              <Link href={`/dashboard/${orgId}/appointments/${nextAppointmentId}`}>
                <Button>View appointment</Button>
              </Link>
            </div>
          ) : null}
        </Card>
      ) : (
        <Card>
          <CardSubtitle>Queue</CardSubtitle>
          <p className="mt-2 text-sm text-ink-muted">Nobody is waiting right now.</p>
        </Card>
      )}

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <StatCard label="Waiting" value={waiting.length} />
        <StatCard label="Today's total" value={todaysAppointments.length} />
        <StatCard label="Completed" value={completedToday} />
        <StatCard label="No-shows" value={noShowToday} />
      </div>

      <div>
        <h2 className="mb-3 text-lg font-semibold text-ink">Today&rsquo;s schedule</h2>
        {todaysAppointments.length === 0 ? (
          <EmptyState title="No appointments today" />
        ) : (
          <div className="flex flex-col gap-2">
            {todaysAppointments.map((a) => (
              <Link key={a.id} href={`/dashboard/${orgId}/appointments/${a.id}`} className="no-underline">
                <Card className="flex flex-row items-center justify-between py-3">
                  <div className="flex items-center gap-3">
                    <span className="w-16 text-sm font-medium text-ink">
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

function StatCard({ label, value }: { label: string; value: number }) {
  return (
    <Card className="py-4 text-center">
      <div className="text-2xl font-bold text-ink">{value}</div>
      <div className="mt-1 text-xs text-ink-muted">{label}</div>
    </Card>
  );
}
