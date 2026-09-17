import type { RequestContext } from "@/lib/context.js";
import { tenantDb } from "@/lib/tenant.js";
import { listMyAccess } from "@/modules/family/service.js";
import {
  Badge,
  Card,
  CardSubtitle,
  Hero,
  HeroActions,
  HeroLabel,
  HeroMain,
  HeroSide,
  LinkButton,
  SideStat,
  StatTile,
} from "@/components/ui/index.js";
import { CalendarIcon, CheckIcon, PillIcon, UsersIcon } from "@/components/dashboard-icons.js";

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

export async function PatientOverview({ ctx, orgId }: { ctx: RequestContext; orgId: string }) {
  const t = tenantDb(ctx);

  const patient = await t.patient.findFirst({
    where: { organizationId: orgId, ownerUserId: ctx.userId },
    select: { id: true, firstName: true },
  });

  const [next, upcomingCount, pastVisitCount, activeMedications, myAccess] = await Promise.all([
    patient
      ? t.appointment.findFirst({
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
      : null,
    patient
      ? t.appointment.count({
          where: {
            organizationId: orgId,
            patientId: patient.id,
            scheduledStart: { gte: new Date() },
            status: { notIn: ["CANCELLED", "NO_SHOW", "RESCHEDULED"] },
          },
        })
      : 0,
    patient
      ? t.appointment.count({ where: { organizationId: orgId, patientId: patient.id, status: "COMPLETED" } })
      : 0,
    patient
      ? t.medication.count({ where: { organizationId: orgId, patientId: patient.id, isActive: true } })
      : 0,
    listMyAccess(ctx),
  ]);

  const familyCount = myAccess.data.length;
  const nextWhen = next
    ? new Date(next.scheduledStart).toLocaleString(undefined, {
        weekday: "long",
        month: "long",
        day: "numeric",
        hour: "2-digit",
        minute: "2-digit",
      })
    : null;

  return (
    <div className="flex flex-col gap-7">
      <h1 className="font-display text-2xl font-bold text-ink">
        {greeting()}
        {patient?.firstName ? `, ${patient.firstName}` : ""}
      </h1>

      {next ? (
        <Hero>
          <HeroMain>
            <div>
              <HeroLabel>Next appointment</HeroLabel>
              <h2 className="relative mt-1 font-display text-xl font-bold">{next.doctor.displayName}</h2>
              {next.doctor.specialty ? <p className="relative text-sm text-white/85">{next.doctor.specialty}</p> : null}
              <p className="relative mt-2 text-[13px] font-medium text-white/90">{nextWhen}</p>
              <div className="relative mt-3 flex flex-wrap items-center gap-2">
                <Badge tone="glass">{STATUS_LABEL[next.status] ?? next.status}</Badge>
                {next.queueEntry ? <Badge tone="glass">Token {next.queueEntry.tokenNumber}</Badge> : null}
              </div>
            </div>
            <HeroActions>
              <LinkButton variant="light" href={`/dashboard/${orgId}/appointments/${next.id}`}>
                View appointment
              </LinkButton>
              <LinkButton variant="glass" href={`/dashboard/${orgId}/appointments/${next.id}/reschedule`}>
                Reschedule
              </LinkButton>
            </HeroActions>
          </HeroMain>
          <HeroSide>
            <SideStat
              value={next.queueEntry ? next.queueEntry.tokenNumber : "—"}
              label={next.queueEntry ? "Your token" : "Not checked in yet"}
              sub={next.queueEntry ? `Status: ${next.queueEntry.state.toLowerCase()}` : "Check in when you arrive"}
            />
            <Card className="flex flex-1 flex-col gap-3">
              <CardSubtitle>Active prescriptions</CardSubtitle>
              {activeMedications === 0 ? (
                <p className="text-[13px] text-ink-muted">Nothing active right now.</p>
              ) : (
                <p className="font-display text-2xl font-bold text-ink">{activeMedications}</p>
              )}
            </Card>
          </HeroSide>
        </Hero>
      ) : (
        <Card>
          <CardSubtitle>You have no upcoming appointments</CardSubtitle>
          <p className="mt-2 text-sm text-ink-muted">Book one from a doctor&rsquo;s profile, or below.</p>
        </Card>
      )}

      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <StatTile icon={<CalendarIcon />} tone="indigo" label="Upcoming" value={upcomingCount} />
        <StatTile icon={<CheckIcon />} tone="ok" label="Past visits" value={pastVisitCount} />
        <StatTile icon={<PillIcon />} tone="coral" label="Prescriptions" value={activeMedications} />
        <StatTile icon={<UsersIcon />} tone="neutral" label="Family linked" value={familyCount} />
      </div>

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
