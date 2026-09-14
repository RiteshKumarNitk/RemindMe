import { requireOrgContext } from "@/lib/web-context.js";
import { getDoctor } from "@/modules/doctors/service.js";
import { getRules, listExceptions } from "@/modules/availability/service.js";
import { Button, Card, EmptyState, ErrorNote, Field, Select, SectionTitle, table, td, th } from "../../../../ui.js";
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
    <div>
      <SectionTitle>Availability — {doctor.displayName}</SectionTitle>
      <ErrorNote message={error} />

      <Card style={{ marginBottom: 20 }}>
        <form action={saveAvailabilityAction.bind(null, orgId, doctorId)}>
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>Day</th>
                <th style={th}>Open</th>
                <th style={th}>Start</th>
                <th style={th}>End</th>
                <th style={th}>Slot (min)</th>
              </tr>
            </thead>
            <tbody>
              {WEEKDAYS.map((wd) => {
                const r = byWeekday.get(wd.n);
                return (
                  <tr key={wd.n}>
                    <td style={td}>{wd.label}</td>
                    <td style={td}>
                      <input type="checkbox" name={`open-${wd.n}`} defaultChecked={!!r} />
                    </td>
                    <td style={td}>
                      <input type="time" name={`start-${wd.n}`} defaultValue={r ? fromMinutes(r.startMinute) : "09:00"} />
                    </td>
                    <td style={td}>
                      <input type="time" name={`end-${wd.n}`} defaultValue={r ? fromMinutes(r.endMinute) : "17:00"} />
                    </td>
                    <td style={td}>
                      <input
                        type="number"
                        name={`slot-${wd.n}`}
                        min={5}
                        max={240}
                        defaultValue={r?.slotMinutes ?? 15}
                        style={{ width: 64 }}
                      />
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
          <div style={{ marginTop: 14 }}>
            <Button>Save weekly schedule</Button>
          </div>
        </form>
      </Card>

      <SectionTitle>Exceptions (leave, holidays, extra hours)</SectionTitle>
      <Card style={{ marginBottom: 20 }}>
        {exceptions.length === 0 ? (
          <EmptyState>No exceptions.</EmptyState>
        ) : (
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>Kind</th>
                <th style={th}>From</th>
                <th style={th}>To</th>
                <th style={th}>Reason</th>
                <th style={th} />
              </tr>
            </thead>
            <tbody>
              {exceptions.map((ex) => (
                <tr key={ex.id}>
                  <td style={td}>{ex.kind}</td>
                  <td style={td}>{new Date(ex.startsAt).toLocaleDateString()}</td>
                  <td style={td}>{new Date(ex.endsAt).toLocaleDateString()}</td>
                  <td style={td}>{ex.reason ?? "—"}</td>
                  <td style={td}>
                    <form action={deleteExceptionAction.bind(null, orgId, doctorId, ex.id)}>
                      <Button variant="danger" type="submit">
                        Remove
                      </Button>
                    </form>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Card style={{ maxWidth: 420 }}>
        <SectionTitle>Add an exception</SectionTitle>
        <form action={addExceptionAction.bind(null, orgId, doctorId)}>
          <Select label="Kind" name="kind" defaultValue="DAY_OFF">
            <option value="DAY_OFF">Day off</option>
            <option value="HOLIDAY">Holiday</option>
            <option value="LEAVE">Leave</option>
            <option value="EXTRA_HOURS">Extra hours</option>
            <option value="BREAK">Break</option>
          </Select>
          <Field label="Date" name="date" type="date" required />
          <Field label="Reason" name="reason" placeholder="Optional" />
          <div style={{ marginTop: 8 }}>
            <Button>Add exception</Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
