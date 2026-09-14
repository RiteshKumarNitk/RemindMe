import { db } from "@/lib/db.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { listDoctors } from "@/modules/doctors/service.js";
import { getBoard } from "@/modules/queue/service.js";
import { AutoRefresh } from "../../AutoRefresh.js";
import { Badge, Button, Card, EmptyState, ErrorNote, SectionTitle, table, td, th } from "../../ui.js";
import { queueAction } from "./actions.js";

export const dynamic = "force-dynamic";

const STATE_TONE: Record<string, "indigo" | "coral" | "ok" | "muted"> = {
  WAITING: "indigo",
  CALLED: "coral",
  IN_CONSULTATION: "coral",
  COMPLETED: "ok",
  SKIPPED: "muted",
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
      <div>
        <SectionTitle>Queue</SectionTitle>
        <EmptyState>Add a doctor first.</EmptyState>
      </div>
    );
  }

  const board = await getBoard(ctx, { doctorId, date: sp.date });
  const redirectQuery = `doctorId=${doctorId}${sp.date ? `&date=${sp.date}` : ""}`;

  return (
    <div>
      <AutoRefresh seconds={10} />
      <SectionTitle>Queue — {board.queueDate}</SectionTitle>
      <ErrorNote message={sp.error} />

      <form style={{ display: "flex", gap: 10, marginBottom: 16, maxWidth: 420 }}>
        <select name="doctorId" defaultValue={doctorId} style={{ flex: 1, padding: "8px 10px", borderRadius: 10, border: "1px solid var(--border)" }}>
          {doctors.map((d) => (
            <option key={d.id} value={d.id}>
              {d.displayName}
            </option>
          ))}
        </select>
        <input type="date" name="date" defaultValue={sp.date} style={{ padding: "8px 10px", borderRadius: 10, border: "1px solid var(--border)" }} />
        <Button variant="ghost" type="submit">
          View
        </Button>
      </form>

      <Card>
        <div style={{ marginBottom: 12, fontSize: 14 }}>
          Now serving: <strong>{board.nowServingToken ?? "—"}</strong>
        </div>
        {board.entries.length === 0 ? (
          <EmptyState>No one checked in yet for this day.</EmptyState>
        ) : (
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>Token</th>
                <th style={th}>Patient</th>
                <th style={th}>State</th>
                <th style={th}>Ahead</th>
                <th style={th}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {board.entries.map((e) => (
                <tr key={e.id}>
                  <td style={td}>#{e.tokenNumber}</td>
                  <td style={td}>
                    {e.patient.firstName} {e.patient.lastName}
                  </td>
                  <td style={td}>
                    <Badge tone={STATE_TONE[e.state] ?? "muted"}>{e.state}</Badge>
                  </td>
                  <td style={td}>{e.ahead}</td>
                  <td style={td}>
                    <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                      {role !== "DOCTOR" && e.state === "WAITING" && (
                        <form action={queueAction.bind(null, orgId, e.id, "CALL", redirectQuery)}>
                          <Button variant="ghost">Call</Button>
                        </form>
                      )}
                      {role !== "DOCTOR" && (e.state === "CALLED" || e.state === "SKIPPED") && (
                        <form action={queueAction.bind(null, orgId, e.id, "RECALL", redirectQuery)}>
                          <Button variant="ghost">Recall</Button>
                        </form>
                      )}
                      {role !== "DOCTOR" && (e.state === "WAITING" || e.state === "CALLED") && (
                        <form action={queueAction.bind(null, orgId, e.id, "SKIP", redirectQuery)}>
                          <Button variant="ghost">Skip</Button>
                        </form>
                      )}
                      {role === "DOCTOR" && e.state === "CALLED" && (
                        <form action={queueAction.bind(null, orgId, e.id, "START", redirectQuery)}>
                          <Button variant="ghost">Start</Button>
                        </form>
                      )}
                      {role === "DOCTOR" && e.state === "IN_CONSULTATION" && (
                        <form action={queueAction.bind(null, orgId, e.id, "COMPLETE", redirectQuery)}>
                          <Button variant="ghost">Complete</Button>
                        </form>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>
    </div>
  );
}
