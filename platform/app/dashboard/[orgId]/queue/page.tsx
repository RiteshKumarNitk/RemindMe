import { db } from "@/lib/db.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { listDoctors } from "@/modules/doctors/service.js";
import { getBoard } from "@/modules/queue/service.js";
import { AutoRefresh } from "../../AutoRefresh.js";
import { Badge, Button, Card, EmptyState, Field, InitialsAvatar, Input, Notice, Select } from "@/components/ui/index.js";
import { queueAction } from "./actions.js";

export const dynamic = "force-dynamic";

const STATE_TONE: Record<string, "indigo" | "coral" | "ok" | "neutral"> = {
  WAITING: "indigo",
  CALLED: "coral",
  IN_CONSULTATION: "coral",
  COMPLETED: "ok",
  SKIPPED: "neutral",
};

export default async function QueuePage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ doctorId?: string; date?: string; error?: string }>;
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

  const board = await getBoard(ctx, { doctorId, date: sp.date });
  const redirectQuery = `doctorId=${doctorId}${sp.date ? `&date=${sp.date}` : ""}`;

  return (
    <div className="flex flex-col gap-7">
      <AutoRefresh seconds={10} />
      <h1 className="font-display text-2xl font-bold text-ink">Queue — {board.queueDate}</h1>
      {sp.error ? <Notice tone="down">{sp.error}</Notice> : null}

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

      <div className="flex items-center gap-4 rounded-2xl border border-border bg-card p-5">
        <div className="font-display text-3xl font-bold tabular-nums text-indigo">{board.nowServingToken ?? "—"}</div>
        <div className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Now serving</div>
      </div>

      {board.entries.length === 0 ? (
        <Card>
          <EmptyState title="No one checked in yet for this day." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {board.entries.map((e) => (
            <Card key={e.id} className="p-4!">
              <div className="flex items-center gap-3">
                <div className="flex h-8.5 w-8.5 shrink-0 items-center justify-center rounded-control bg-indigo/10 font-display text-[12.5px] font-bold tabular-nums text-indigo-dark">
                  {e.tokenNumber}
                </div>
                <InitialsAvatar name={`${e.patient.firstName} ${e.patient.lastName}`} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13.5px] font-semibold text-ink">
                    {e.patient.firstName} {e.patient.lastName}
                  </div>
                  <div className="text-[11.5px] text-ink-muted">{e.ahead} ahead</div>
                </div>
                <Badge tone={STATE_TONE[e.state] ?? "neutral"}>{e.state}</Badge>
              </div>

              {(role !== "DOCTOR" && ["WAITING", "CALLED", "SKIPPED"].includes(e.state)) ||
              (role === "DOCTOR" && ["CALLED", "IN_CONSULTATION"].includes(e.state)) ? (
                <div className="mt-3 flex flex-wrap gap-2 border-t border-border pt-3">
                  {role !== "DOCTOR" && e.state === "WAITING" && (
                    <form action={queueAction.bind(null, orgId, e.id, "CALL", redirectQuery)}>
                      <Button variant="ghost" size="sm">
                        Call
                      </Button>
                    </form>
                  )}
                  {role !== "DOCTOR" && (e.state === "CALLED" || e.state === "SKIPPED") && (
                    <form action={queueAction.bind(null, orgId, e.id, "RECALL", redirectQuery)}>
                      <Button variant="ghost" size="sm">
                        Recall
                      </Button>
                    </form>
                  )}
                  {role !== "DOCTOR" && (e.state === "WAITING" || e.state === "CALLED") && (
                    <form action={queueAction.bind(null, orgId, e.id, "SKIP", redirectQuery)}>
                      <Button variant="ghost" size="sm">
                        Skip
                      </Button>
                    </form>
                  )}
                  {role === "DOCTOR" && e.state === "CALLED" && (
                    <form action={queueAction.bind(null, orgId, e.id, "START", redirectQuery)}>
                      <Button variant="ghost" size="sm">
                        Start
                      </Button>
                    </form>
                  )}
                  {role === "DOCTOR" && e.state === "IN_CONSULTATION" && (
                    <form action={queueAction.bind(null, orgId, e.id, "COMPLETE", redirectQuery)}>
                      <Button variant="ghost" size="sm">
                        Complete
                      </Button>
                    </form>
                  )}
                </div>
              ) : null}
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
