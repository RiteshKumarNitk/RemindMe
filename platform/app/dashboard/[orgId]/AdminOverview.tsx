import Link from "next/link";
import type { RequestContext } from "@/lib/context.js";
import { tenantDb } from "@/lib/tenant.js";
import { getOrgInsights, type OrgInsights } from "@/modules/clinics/insights.js";
import { listAppointments } from "@/modules/appointments/service.js";
import {
  AttentionList,
  Badge,
  Card,
  CardSubtitle,
  CompletionMeter,
  EmptyState,
  InitialsAvatar,
  LinkButton,
  StatTile,
  statusLabel,
  statusTone,
  type AttentionItem,
} from "@/components/ui/index.js";
import { BuildingIcon, CalendarIcon, CheckIcon, ClockIcon, UsersIcon } from "@/components/dashboard-icons.js";

/**
 * Clinic-owner dashboard (request §7): answers "is my clinic operating
 * correctly?" in the spec's information hierarchy (§29):
 *   1. current state        → lifecycle band + today's numbers
 *   2. important attention  → AttentionList (profile/verification/availability gaps)
 *   3. primary actions      → action row
 *   4. operational info     → per-doctor today + today's schedule
 * Not a wall of KPI tiles — every number links somewhere actionable.
 */
export async function AdminOverview({ ctx, orgId }: { ctx: RequestContext; orgId: string }) {
  const t = tenantDb(ctx);
  const todayStart = new Date();
  todayStart.setHours(0, 0, 0, 0);
  const todayEnd = new Date(todayStart.getTime() + 86_400_000);

  const [insights, todaysResult, doctorRows] = await Promise.all([
    getOrgInsights(ctx, orgId),
    listAppointments(ctx, { from: todayStart.toISOString(), to: todayEnd.toISOString(), limit: 200 }),
    // Per-doctor operational breakdown (§22) — owner sees today's load by doctor.
    t.doctorProfile.findMany({
      where: { organizationId: orgId, isActive: true },
      select: { id: true, displayName: true, specialty: true },
      orderBy: { displayName: "asc" },
    }),
  ]);
  const todaysAppointments = todaysResult.data;

  const byStatus = groupBy(todaysAppointments, (a) => a.status);
  const perDoctor = doctorRows.map((d) => ({
    ...d,
    total: todaysAppointments.filter((a) => a.doctorId === d.id).length,
    completed: byStatus["COMPLETED"]?.filter((a) => a.doctorId === d.id).length ?? 0,
    waiting:
      (byStatus["WAITING"]?.filter((a) => a.doctorId === d.id).length ?? 0) +
      (byStatus["CHECKED_IN"]?.filter((a) => a.doctorId === d.id).length ?? 0),
  }));

  const completed = byStatus["COMPLETED"]?.length ?? 0;
  const checkedIn = byStatus["CHECKED_IN"]?.length ?? 0;
  const waiting = (byStatus["WAITING"]?.length ?? 0) + checkedIn;
  const inConsultation = (byStatus["IN_CONSULTATION"]?.length ?? 0) + (byStatus["CALLED"]?.length ?? 0);
  const pending = (byStatus["REQUESTED"]?.length ?? 0) + (byStatus["CONFIRMED"]?.length ?? 0);
  const noShows = byStatus["NO_SHOW"]?.length ?? 0;
  const cancelled = byStatus["CANCELLED"]?.length ?? 0;

  const recent = [...todaysAppointments]
    .sort((a, b) => +new Date(a.scheduledStart) - +new Date(b.scheduledStart))
    .slice(0, 6);

  const attention = buildAttention(insights, orgId);

  return (
    <div className="flex flex-col gap-7">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h1 className="font-display text-2xl font-bold text-ink">{insights.org.name}</h1>
          <p className="mt-0.5 text-sm text-ink-muted">Clinic overview</p>
        </div>
        <div className="flex items-center gap-2">
          <Badge tone={insights.lifecycle.tone}>{insights.lifecycle.label}</Badge>
          <LinkButton variant="ghost" size="sm" href={`/hospitals/${insights.org.slug}`}>
            Preview public profile ↗
          </LinkButton>
        </div>
      </div>

      <AttentionList items={attention} />

      <div className="grid gap-4 lg:grid-cols-[1.4fr_1fr]">
        {/* Public profile band (§7): lifecycle + completeness meter side by side. */}
        <Card className="flex flex-col gap-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <CardSubtitle>Public profile</CardSubtitle>
            <Badge tone={insights.lifecycle.tone}>{insights.lifecycle.label}</Badge>
          </div>
          <CompletionMeter completeness={insights.completeness} />
          {insights.lifecycle.readinessReasons.length > 0 ? (
            <ul className="flex list-disc flex-col gap-1 pl-5 text-[13px] text-ink-muted">
              {insights.lifecycle.readinessReasons.map((r) => (
                <li key={r}>{r}</li>
              ))}
            </ul>
          ) : null}
          <div className="flex flex-wrap gap-2">
            {insights.lifecycle.code === "PUBLISHED" ? (
              <LinkButton variant="secondary" size="sm" href={`/dashboard/${orgId}/profile`}>
                Manage listing
              </LinkButton>
            ) : (
              <LinkButton variant="primary" size="sm" href={`/dashboard/${orgId}/setup`}>
                Complete profile
              </LinkButton>
            )}
            <LinkButton variant="ghost" size="sm" href={`/dashboard/${orgId}/profile`}>
              Verification status
            </LinkButton>
          </div>
        </Card>

        {/* Today's operation (§7 "Today's Overview"). */}
        <Card className="flex flex-col gap-3">
          <CardSubtitle>Today</CardSubtitle>
          <div className="grid grid-cols-2 gap-x-4 gap-y-2.5">
            <TodayLine label="Appointments" value={todaysAppointments.length} tone="text-ink" />
            <TodayLine label="Checked in" value={checkedIn} tone="text-indigo" />
            <TodayLine label="Waiting" value={waiting} tone="text-warn" />
            <TodayLine label="In consultation" value={inConsultation} tone="text-coral" />
            <TodayLine label="Completed" value={completed} tone="text-ok" />
            <TodayLine label="No-shows" value={noShows} tone="text-down" />
          </div>
          <div className="mt-1 flex flex-wrap gap-2">
            <LinkButton size="sm" href={`/dashboard/${orgId}/queue`}>
              Open queue board
            </LinkButton>
            <LinkButton variant="secondary" size="sm" href={`/dashboard/${orgId}/appointments`}>
              All appointments
            </LinkButton>
          </div>
        </Card>
      </div>

      {/* Per-doctor load (§22) — the owner's view of who is carrying what today. */}
      {perDoctor.length > 0 ? (
        <section aria-label="Doctors today">
          <h2 className="mb-3 font-display text-lg font-bold text-ink">Doctors today</h2>
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {perDoctor.map((d) => (
              <Link
                key={d.id}
                href={`/dashboard/${orgId}/appointments?doctorId=${d.id}`}
                className="no-underline"
              >
                <Card className="flex items-center gap-3 transition-colors hover:border-indigo">
                  <InitialsAvatar name={d.displayName} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[13.5px] font-semibold text-ink">{d.displayName}</div>
                    <div className="truncate text-[11.5px] text-ink-muted">
                      {d.specialty ?? "—"} · {d.total} today
                      {d.waiting > 0 ? ` · ${d.waiting} waiting` : ""}
                      {d.total > 0 && d.completed === d.total ? " · all done" : ""}
                    </div>
                  </div>
                  <span className="font-display text-lg font-bold tabular-nums text-ink">{d.total}</span>
                </Card>
              </Link>
            ))}
          </div>
        </section>
      ) : (
        <EmptyState
          title="No doctors yet"
          description="Doctors, their availability and the appointment types they book against are the backbone of the clinic."
          action={
            <LinkButton href={`/dashboard/${orgId}/doctors`}>Add your first doctor</LinkButton>
          }
        />
      )}

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
                  <div className="truncate text-[11.5px] text-ink-muted">
                    {a.doctor.displayName}
                    {a.location ? ` · ${a.location.name}` : ""}
                  </div>
                </div>
                <Badge tone={statusTone(a.status)}>{statusLabel(a.status)}</Badge>
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

function TodayLine({ label, value, tone }: { label: string; value: number; tone: string }) {
  return (
    <div className="flex items-baseline justify-between gap-2">
      <span className="text-[12.5px] text-ink-muted">{label}</span>
      <span className={`font-display text-lg font-bold tabular-nums ${tone}`}>{value}</span>
    </div>
  );
}

function groupBy<T>(rows: Array<T>, key: (row: T) => string): Record<string, Array<T>> {
  const out: Record<string, Array<T>> = {};
  for (const row of rows) {
    (out[key(row)] ??= []).push(row);
  }
  return out;
}

function buildAttention(insights: OrgInsights, orgId: string): Array<AttentionItem> {
  const items: Array<AttentionItem> = [];
  const missingKeys = new Set(insights.completeness.missing.map((m) => m.key));

  if (insights.lifecycle.code === "SUSPENDED") {
    items.push({
      key: "suspended",
      severity: "danger",
      title: "This clinic has been suspended by the platform — contact DoseWise support.",
    });
  }
  if (insights.lifecycle.code === "REJECTED") {
    items.push({
      key: "rejected",
      severity: "danger",
      title: "Verification was rejected — update the profile and request review again.",
      href: `/dashboard/${orgId}/profile`,
      actionLabel: "Review",
    });
  }
  if (missingKeys.has("location")) {
    items.push({
      key: "location",
      severity: "danger",
      title: "No location added — patients need at least one branch to book against.",
      href: `/dashboard/${orgId}/settings`,
      actionLabel: "Add location",
    });
  }
  if (insights.counts.activeDoctors === 0) {
    items.push({
      key: "doctors",
      severity: "danger",
      title: "No active doctors — appointments can't be booked.",
      href: `/dashboard/${orgId}/doctors`,
      actionLabel: "Add doctor",
    });
  }
  if (insights.counts.doctorsWithoutAvailability > 0) {
    const names = insights.doctorsWithoutAvailabilityNames;
    const who =
      names.length <= 2 ? names.join(" and ") : `${names[0]}, ${names[1]} and ${names.length - 2} more`;
    items.push({
      key: "availability",
      severity: "warn",
      title: `Doctor availability missing for ${insights.counts.doctorsWithoutAvailability} doctor${insights.counts.doctorsWithoutAvailability === 1 ? "" : "s"} (${who}) — their calendars book nothing until set up.`,
      href: `/dashboard/${orgId}/doctors`,
      actionLabel: "Fix now",
    });
  }
  if (insights.counts.appointmentTypes === 0) {
    items.push({
      key: "types",
      severity: "warn",
      title: "No appointment types configured — bookings use the default 15-minute slot.",
      href: `/dashboard/${orgId}/settings`,
      actionLabel: "Add types",
    });
  }
  if (missingKeys.has("description") || missingKeys.has("contact")) {
    items.push({
      key: "publicInfo",
      severity: "warn",
      title: "Public profile is missing core information (description or contact).",
      href: `/dashboard/${orgId}/profile`,
      actionLabel: "Complete",
    });
  }
  if (insights.lifecycle.code === "DRAFT" && insights.completeness.percent >= 60) {
    items.push({
      key: "verification",
      severity: "info",
      title: "Profile looks substantial — request verification so patients see the verified badge.",
      href: `/dashboard/${orgId}/profile`,
      actionLabel: "Request",
    });
  }
  if (insights.lifecycle.code === "READY_TO_PUBLISH") {
    items.push({
      key: "publish",
      severity: "info",
      title: "This clinic is ready to appear in public discovery.",
      href: `/dashboard/${orgId}/profile`,
      actionLabel: "Publish",
    });
  }
  if (insights.lifecycle.code === "VERIFIED_UNLISTED") {
    items.push({
      key: "publish",
      severity: "info",
      title: "Verified — publish the profile so patients can find you on DoseWise.",
      href: `/dashboard/${orgId}/profile`,
      actionLabel: "Publish",
    });
  }
  return items;
}
