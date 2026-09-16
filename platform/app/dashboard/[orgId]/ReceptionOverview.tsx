import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { listAppointments } from "@/modules/appointments/service.js";
import { Badge, Button, Card, EmptyState } from "@/components/ui/index.js";

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
    <div className="flex max-w-3xl flex-col gap-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-semibold text-ink">
          {new Date().toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" })}
        </h1>
        <div className="flex gap-2">
          <Link href={`/dashboard/${orgId}/patients`}>
            <Button variant="secondary">Search patient</Button>
          </Link>
          <Link href={`/dashboard/${orgId}/queue`}>
            <Button>Open queue board</Button>
          </Link>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
        <StatCard label="Today's total" value={todaysAppointments.length} />
        <StatCard label="Checked in" value={checkedIn} />
        <StatCard label="Waiting" value={waiting} />
        <StatCard label="In consultation" value={inConsultation} />
        <StatCard label="No-shows" value={noShows} />
      </div>

      <div>
        <h2 className="mb-3 text-lg font-semibold text-ink">Up next</h2>
        {upNext.length === 0 ? (
          <EmptyState title="Nothing left on today's schedule" />
        ) : (
          <div className="flex flex-col gap-2">
            {upNext.map((a) => (
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
      </div>

      <Link href={`/dashboard/${orgId}/appointments`}>
        <Button variant="secondary">+ New appointment</Button>
      </Link>
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
