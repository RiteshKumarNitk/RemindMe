import { requireOrgContext } from "@/lib/web-context.js";
import { getDoctor } from "@/modules/doctors/service.js";
import { getRules, listExceptions } from "@/modules/availability/service.js";
import { Badge, Button, Card, CardSubtitle, EmptyState, Field, Input, Notice, Select } from "@/components/ui/index.js";
import { addExceptionAction, deleteExceptionAction, saveAvailabilityAction } from "./actions.js";

export const dynamic = "force-dynamic";

const WEEKDAYS: Array<{ n: number; label: string }> = [
  { n: 1, label: "Monday" },
  { n: 2, label: "Tuesday" },
  { n: 3, label: "Wednesday" },
  { n: 4, label: "Thursday" },
  { n: 5, label: "Friday" },
  { n: 6, label: "Saturday" },
  { n: 7, label: "Sunday" },
];

const KIND_TONE: Record<string, "warn" | "coral" | "ok" | "indigo"> = {
  DAY_OFF: "warn",
  HOLIDAY: "coral",
  LEAVE: "warn",
  EXTRA_HOURS: "ok",
  BREAK: "indigo",
};

function fromMinutes(min: number): string {
  const h = Math.floor(min / 60)
    .toString()
    .padStart(2, "0");
  const m = (min % 60).toString().padStart(2, "0");
  return `${h}:${m}`;
}

export default async function AvailabilityPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string; doctorId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId, doctorId } = await params;
  const ctx = await requireOrgContext(orgId);
  const { error } = await searchParams;
  const [doctor, rules, exceptions] = await Promise.all([
    getDoctor(ctx, doctorId),
    getRules(ctx, doctorId),
    listExceptions(ctx, doctorId),
  ]);
  const byWeekday = new Map(rules.map((r) => [r.weekday, r]));

  return (
    <div className="flex flex-col gap-7">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Availability</h1>
        <p className="mt-1 text-sm text-ink-muted">{doctor.displayName}</p>
      </div>
      {error ? <Notice tone="down">{error}</Notice> : null}

      <Card>
        <CardSubtitle>Weekly schedule</CardSubtitle>
        <form action={saveAvailabilityAction.bind(null, orgId, doctorId)} className="mt-4">
          <div className="overflow-x-auto">
            <table className="w-full min-w-125 border-collapse text-[13px]">
              <thead>
                <tr className="text-left text-[10.5px] font-semibold uppercase tracking-wide text-ink-faint">
                  <th className="pb-2 pr-3">Day</th>
                  <th className="pb-2 pr-3">Open</th>
                  <th className="pb-2 pr-3">Start</th>
                  <th className="pb-2 pr-3">End</th>
                  <th className="pb-2">Slot (min)</th>
                </tr>
              </thead>
              <tbody>
                {WEEKDAYS.map((wd) => {
                  const r = byWeekday.get(wd.n);
                  return (
                    <tr key={wd.n} className="border-t border-border">
                      <td className="py-2.5 pr-3 font-medium text-ink">{wd.label}</td>
                      <td className="py-2.5 pr-3">
                        <input type="checkbox" name={`open-${wd.n}`} defaultChecked={!!r} className="h-4 w-4 accent-indigo" />
                      </td>
                      <td className="py-2.5 pr-3">
                        <Input type="time" name={`start-${wd.n}`} defaultValue={r ? fromMinutes(r.startMinute) : "09:00"} />
                      </td>
                      <td className="py-2.5 pr-3">
                        <Input type="time" name={`end-${wd.n}`} defaultValue={r ? fromMinutes(r.endMinute) : "17:00"} />
                      </td>
                      <td className="py-2.5">
                        <Input type="number" name={`slot-${wd.n}`} min={5} max={240} defaultValue={r?.slotMinutes ?? 15} className="w-18" />
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
          <Button className="mt-4">Save weekly schedule</Button>
        </form>
      </Card>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Exceptions</h2>
        <p className="mb-3 -mt-2 text-sm text-ink-muted">Leave, holidays, or extra hours on top of the weekly schedule.</p>
        <Card>
          {exceptions.length === 0 ? (
            <EmptyState title="No exceptions." />
          ) : (
            <div className="flex flex-col">
              {exceptions.map((ex, i) => (
                <div
                  key={ex.id}
                  className={`flex flex-wrap items-center gap-3 py-2.5 ${i < exceptions.length - 1 ? "border-b border-border" : ""}`}
                >
                  <Badge tone={KIND_TONE[ex.kind] ?? "neutral"}>{ex.kind.replaceAll("_", " ")}</Badge>
                  <span className="text-[13px] text-ink">
                    {new Date(ex.startsAt).toLocaleDateString()} – {new Date(ex.endsAt).toLocaleDateString()}
                  </span>
                  {ex.reason ? <span className="text-[12px] text-ink-muted">{ex.reason}</span> : null}
                  <form action={deleteExceptionAction.bind(null, orgId, doctorId, ex.id)} className="ml-auto">
                    <Button variant="danger" size="sm" type="submit">
                      Remove
                    </Button>
                  </form>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>

      <Card className="max-w-md">
        <CardSubtitle>Add an exception</CardSubtitle>
        <form action={addExceptionAction.bind(null, orgId, doctorId)} className="mt-4 flex flex-col gap-4">
          <Field label="Kind">
            <Select name="kind" defaultValue="DAY_OFF" className="w-full">
              <option value="DAY_OFF">Day off</option>
              <option value="HOLIDAY">Holiday</option>
              <option value="LEAVE">Leave</option>
              <option value="EXTRA_HOURS">Extra hours</option>
              <option value="BREAK">Break</option>
            </Select>
          </Field>
          <Field label="Date">
            <Input name="date" type="date" required className="w-full" />
          </Field>
          <Field label="Reason" hint="Optional">
            <Input name="reason" className="w-full" />
          </Field>
          <Button className="self-start">Add exception</Button>
        </form>
      </Card>
    </div>
  );
}
