import { db } from "@/lib/db.js";
import { Badge, Card, CardSubtitle, CardTitle, LinkButton } from "@/components/ui/index.js";

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

const STATUS_LABEL: Record<string, string> = {
  REQUESTED: "Requested — awaiting confirmation",
  CONFIRMED: "Confirmed",
  CHECKED_IN: "Checked in",
  WAITING: "Waiting",
  IN_CONSULTATION: "In consultation",
};

export async function PatientOverview({ orgId, userId }: { orgId: string; userId: string }) {
  const patient = await db.patient.findFirst({
    where: { organizationId: orgId, ownerUserId: userId },
    select: { id: true, firstName: true },
  });

  const next = patient
    ? await db.appointment.findFirst({
        where: {
          organizationId: orgId,
          patientId: patient.id,
          status: { in: ["REQUESTED", "CONFIRMED", "CHECKED_IN", "WAITING", "IN_CONSULTATION"] },
        },
        orderBy: { scheduledStart: "asc" },
        include: {
          doctor: { select: { displayName: true, specialty: true } },
          queueEntry: { select: { tokenNumber: true, state: true } },
        },
      })
    : null;

  const upcomingCount = patient
    ? await db.appointment.count({
        where: {
          organizationId: orgId,
          patientId: patient.id,
          scheduledStart: { gte: new Date() },
          status: { notIn: ["CANCELLED", "NO_SHOW", "RESCHEDULED"] },
        },
      })
    : 0;

  return (
    <div className="flex max-w-2xl flex-col gap-6">
      <h1 className="text-2xl font-semibold text-ink">{greeting()}{patient?.firstName ? `, ${patient.firstName}` : ""}</h1>

      {next ? (
        <Card>
          <CardSubtitle>Your next appointment</CardSubtitle>
          <CardTitle className="mt-1 text-lg">{next.doctor.displayName}</CardTitle>
          {next.doctor.specialty ? <p className="text-sm text-ink-muted">{next.doctor.specialty}</p> : null}
          <p className="mt-3 text-sm font-medium text-ink">
            {new Date(next.scheduledStart).toLocaleString(undefined, {
              weekday: "long",
              month: "long",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })}
          </p>
          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Badge tone="indigo">{STATUS_LABEL[next.status] ?? next.status}</Badge>
            {next.queueEntry ? <Badge tone="ok">Token {next.queueEntry.tokenNumber}</Badge> : null}
          </div>
          <div className="mt-4">
            <LinkButton variant="secondary" href={`/dashboard/${orgId}/appointments/${next.id}`}>
              View appointment
            </LinkButton>
          </div>
        </Card>
      ) : (
        <Card>
          <CardSubtitle>You have no upcoming appointments</CardSubtitle>
          <p className="mt-2 text-sm text-ink-muted">Book one from a doctor&rsquo;s profile, or below.</p>
        </Card>
      )}

      <div className="flex flex-wrap gap-3">
        <LinkButton href={`/dashboard/${orgId}/appointments`}>Book an appointment</LinkButton>
        <LinkButton variant="secondary" href={`/dashboard/${orgId}/appointments`}>
          {upcomingCount > 0 ? `All appointments (${upcomingCount} upcoming)` : "All appointments"}
        </LinkButton>
        <LinkButton variant="ghost" href={`/dashboard/${orgId}/family`}>
          Family access
        </LinkButton>
      </div>
    </div>
  );
}
