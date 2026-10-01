import { db } from "@/lib/db.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { listDoctors } from "@/modules/doctors/service.js";
import { listPatients } from "@/modules/patients/service.js";
import { getBoard } from "@/modules/queue/service.js";
import { getTokenWindowForStaff } from "@/modules/tokens/service.js";
import type { QueueAction } from "@/modules/queue/state-machine.js";
import { AutoRefresh } from "../../AutoRefresh.js";
import { Badge, Button, Card, EmptyState, Field, InitialsAvatar, Input, Notice, Select, statusLabel, statusTone } from "@/components/ui/index.js";
import { callNextAction, queueAction, walkInAction } from "./actions.js";

export const dynamic = "force-dynamic";

/** Button label per queue action. Which buttons appear is decided server-side
 *  (`getBoard` → `entry.actions`), so this is presentation only. */
const ACTION_LABEL: Record<QueueAction, string> = {
  CALL: "Call",
  RECALL: "Recall",
  SKIP: "Skip",
  START: "Start consultation",
  COMPLETE: "Complete",
  HOLD: "Hold",
  RELEASE: "Back to waiting",
  NO_SHOW: "No-show",
};

type Board = Awaited<ReturnType<typeof getBoard>>;
type Entry = Board["entries"][number];

function SectionLabel({ children, count }: { children: string; count?: number }) {
  return (
    <div className="flex items-center gap-2 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">
      {children}
      {count !== undefined ? <span className="tabular-nums text-ink-muted">{count}</span> : null}
    </div>
  );
}

export default async function QueuePage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ doctorId?: string; date?: string; error?: string; issued?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const role = ctx.org!.role;
  const sp = await searchParams;

  const doctors = await listDoctors(ctx);
  let doctorId = sp.doctorId;
  if (!doctorId && role === "DOCTOR") {
    const mine = await db.doctorProfile.findFirst({
      where: { organizationId: orgId, userId: ctx.userId },
      select: { id: true },
    });
    doctorId = mine?.id;
  }
  doctorId = doctorId ?? doctors[0]?.id;

  if (!doctorId) {
    return (
      <div className="flex flex-col gap-7">
        <h1 className="font-display text-2xl font-bold text-ink">Queue</h1>
        <Card>
          <EmptyState title="Add a doctor first." />
        </Card>
      </div>
    );
  }

  const doctor = doctors.find((d) => d.id === doctorId);
  const isToday = !sp.date;
  const isFrontDesk = role === "RECEPTIONIST" || role === "CLINIC_ADMIN";
  const usesTokens = doctor?.bookingMode === "SAME_DAY_TOKEN" || doctor?.bookingMode === "BOTH";

  const [board, tokenWindow, patients] = await Promise.all([
    getBoard(ctx, { doctorId, date: sp.date }),
    usesTokens && isToday ? getTokenWindowForStaff(ctx, doctorId) : Promise.resolve(null),
    isFrontDesk && isToday ? listPatients(ctx, { limit: 100 }) : Promise.resolve(null),
  ]);
  const redirectQuery = `doctorId=${doctorId}${sp.date ? `&date=${sp.date}` : ""}`;

  const now = board.entries.find((e) => e.state === "IN_CONSULTATION") ?? board.entries.find((e) => e.state === "CALLED") ?? null;
  const waiting = board.entries.filter((e) => e.state === "WAITING");
  const next = waiting[0] ?? null;
  // A cancelled/rescheduled appointment's entry is parked as SKIPPED for
  // history — it belongs with the finished rows, not in the recallable group.
  const withdrawn = (e: Entry) => e.appointment.status === "CANCELLED" || e.appointment.status === "RESCHEDULED";
  const onHold = board.entries.filter((e) => (e.state === "HOLD" || e.state === "SKIPPED") && !withdrawn(e));
  const done = board.entries.filter((e) => e.state === "COMPLETED" || e.state === "NO_SHOW" || withdrawn(e));
  // Anyone besides `now` still CALLED/IN_CONSULTATION (rare: two rooms, stale call).
  const otherActive = board.entries.filter(
    (e) => e.id !== now?.id && (e.state === "CALLED" || e.state === "IN_CONSULTATION"),
  );

  const actionsFor = (e: Entry) =>
    e.actions.length ? (
      <div className="flex flex-wrap gap-1.5">
        {e.actions.map((a) => (
          <form key={a} action={queueAction.bind(null, orgId, e.id, a, redirectQuery)}>
            <Button variant={a === "NO_SHOW" ? "ghost" : "secondary"} size="sm" className={a === "NO_SHOW" ? "text-down" : ""}>
              {ACTION_LABEL[a]}
            </Button>
          </form>
        ))}
      </div>
    ) : null;

  const row = (e: Entry, opts: { showAhead?: boolean } = {}) => (
    <li key={e.id} className="flex flex-wrap items-center gap-3 px-4 py-3">
      <div className="flex h-8.5 w-10 shrink-0 items-center justify-center rounded-control bg-indigo/10 font-display text-[13px] font-bold tabular-nums text-indigo-dark">
        #{e.tokenNumber}
      </div>
      <div className="min-w-0 flex-1">
        <div className="truncate text-[13.5px] font-semibold text-ink">
          {e.patient.firstName} {e.patient.lastName}
        </div>
        <div className="text-[11.5px] text-ink-muted">
          {opts.showAhead ? `${e.ahead} ahead` : statusLabel(withdrawn(e) ? e.appointment.status : e.state)}
          {e.recallCount > 0 ? ` · recalled ${e.recallCount}×` : ""}
        </div>
      </div>
      <Badge tone={statusTone(withdrawn(e) ? e.appointment.status : e.state)}>
        {statusLabel(withdrawn(e) ? e.appointment.status : e.state)}
      </Badge>
      {actionsFor(e)}
    </li>
  );

  return (
    <div className="flex flex-col gap-6">
      {isToday ? <AutoRefresh seconds={10} /> : null}
      <div className="flex flex-wrap items-baseline justify-between gap-2">
        <h1 className="font-display text-2xl font-bold text-ink">
          Queue — {doctor?.displayName ?? "Doctor"} · {board.queueDate}
        </h1>
        <div className="text-sm text-ink-muted tabular-nums">
          {board.summary.total} tokens today
        </div>
      </div>
      {sp.error ? <Notice tone="down">{sp.error}</Notice> : null}
      {sp.issued ? <Notice tone="ok">Token #{sp.issued} issued.</Notice> : null}

      <form className="flex flex-wrap items-end gap-3">
        <div className="min-w-40 flex-1">
          <Field label="Doctor">
            <Select name="doctorId" defaultValue={doctorId} className="w-full">
              {doctors.map((d) => (
                <option key={d.id} value={d.id}>
                  {d.displayName}
                </option>
              ))}
            </Select>
          </Field>
        </div>
        <Field label="Date">
          <Input type="date" name="date" defaultValue={sp.date} />
        </Field>
        <Button variant="secondary" type="submit">
          View
        </Button>
      </form>

      {tokenWindow ? (
        <div className="flex flex-wrap items-center gap-x-4 gap-y-1 rounded-control border border-border bg-card px-4 py-2.5 text-sm">
          <Badge tone={tokenWindow.status === "OPEN" ? "ok" : "neutral"}>
            {tokenWindow.status === "OPEN"
              ? "Token booking open"
              : tokenWindow.status === "NOT_YET_OPEN"
                ? `Opens ${tokenWindow.opensAt}`
                : "Token booking closed"}
          </Badge>
          <span className="text-ink-muted">
            {tokenWindow.opensAt}–{tokenWindow.closesAt} · queue starts {tokenWindow.queueStartAt}
          </span>
          <span className="tabular-nums text-ink-muted">
            {tokenWindow.issued} / {tokenWindow.maxDailyTokens} issued
          </span>
        </div>
      ) : null}

      {/* NOW / NEXT rail */}
      <div className="grid gap-3 sm:grid-cols-2">
        <Card className="p-4!">
          <SectionLabel>Now</SectionLabel>
          {now ? (
            <div className="mt-2 flex flex-col gap-3">
              <div className="flex items-center gap-3">
                <div className="font-display text-3xl font-bold tabular-nums text-indigo">#{now.tokenNumber}</div>
                <InitialsAvatar name={`${now.patient.firstName} ${now.patient.lastName}`} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-semibold text-ink">
                    {now.patient.firstName} {now.patient.lastName}
                  </div>
                  <Badge tone={statusTone(now.state)}>{statusLabel(now.state)}</Badge>
                </div>
              </div>
              {actionsFor(now)}
            </div>
          ) : (
            <p className="mt-2 text-sm text-ink-muted">Nobody is being seen.</p>
          )}
        </Card>
        <Card className="p-4!">
          <SectionLabel>Next</SectionLabel>
          {next ? (
            <div className="mt-2 flex items-center gap-3">
              <div className="font-display text-3xl font-bold tabular-nums text-ink">#{next.tokenNumber}</div>
              <div className="min-w-0 flex-1 truncate text-[14px] font-semibold text-ink">
                {next.patient.firstName} {next.patient.lastName}
              </div>
            </div>
          ) : (
            <p className="mt-2 text-sm text-ink-muted">Nobody waiting.</p>
          )}
          {isToday && (isFrontDesk || role === "DOCTOR") ? (
            <form action={callNextAction.bind(null, orgId, doctorId, redirectQuery)} className="mt-3">
              <Button size="sm" disabled={!next || !!now}>
                Call next
              </Button>
              {now && next ? (
                <span className="ml-2 text-xs text-ink-muted">Finish, hold or skip #{now.tokenNumber} first.</span>
              ) : null}
            </form>
          ) : null}
        </Card>
      </div>

      {otherActive.length ? (
        <Card className="p-0!">
          <div className="px-4 pt-3">
            <SectionLabel count={otherActive.length}>Also called</SectionLabel>
          </div>
          <ul className="divide-y divide-border">{otherActive.map((e) => row(e))}</ul>
        </Card>
      ) : null}

      <Card className="p-0!">
        <div className="px-4 pt-3">
          <SectionLabel count={waiting.length}>Waiting</SectionLabel>
        </div>
        {waiting.length ? (
          <ul className="divide-y divide-border">{waiting.map((e) => row(e, { showAhead: true }))}</ul>
        ) : (
          <p className="px-4 py-3 text-sm text-ink-muted">No one waiting.</p>
        )}
      </Card>

      <Card className="p-0!">
        <div className="px-4 pt-3">
          <SectionLabel count={onHold.length}>On hold / skipped</SectionLabel>
        </div>
        {onHold.length ? (
          <ul className="divide-y divide-border">{onHold.map((e) => row(e))}</ul>
        ) : (
          <p className="px-4 py-3 text-sm text-ink-muted">Nobody on hold.</p>
        )}
      </Card>

      <details className="rounded-2xl border border-border bg-card">
        <summary className="cursor-pointer px-4 py-3">
          <span className="inline-flex">
            <SectionLabel count={done.length}>Completed / no-show / cancelled</SectionLabel>
          </span>
        </summary>
        {done.length ? (
          <ul className="divide-y divide-border border-t border-border">{done.map((e) => row(e))}</ul>
        ) : (
          <p className="px-4 pb-3 text-sm text-ink-muted">None yet.</p>
        )}
      </details>

      {isFrontDesk && isToday && patients ? (
        <Card>
          <SectionLabel>Register at desk</SectionLabel>
          <p className="mt-1 text-sm text-ink-muted">
            Issues today&rsquo;s next token for a patient who walked in. Same window and daily limit as online booking.
            Patients with a scheduled appointment are checked in from Appointments instead.
          </p>
          {usesTokens ? (
            <form action={walkInAction.bind(null, orgId, doctorId, redirectQuery)} className="mt-3 flex flex-wrap items-end gap-3">
              <div className="min-w-48 flex-1">
                <Field label="Patient">
                  <Select name="patientId" required className="w-full" defaultValue="">
                    <option value="" disabled>
                      Choose a patient…
                    </option>
                    {patients.data.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.firstName} {p.lastName}
                        {p.phone ? ` · ${p.phone}` : ""}
                      </option>
                    ))}
                  </Select>
                </Field>
              </div>
              <Button type="submit" disabled={!tokenWindow?.bookable}>
                Issue token
              </Button>
            </form>
          ) : (
            <p className="mt-2 text-sm text-ink-muted">This doctor takes scheduled appointments only.</p>
          )}
        </Card>
      ) : null}

      {board.entries.length === 0 ? (
        <Card>
          <EmptyState title="No tokens yet for this day." />
        </Card>
      ) : null}
    </div>
  );
}
