import { requireOrgContext } from "@/lib/web-context.js";
import { getAppointment } from "@/modules/appointments/service.js";
import { getConsultation } from "@/modules/consultations/service.js";
import { Badge, Button, Card, EmptyState, ErrorNote, Field, SectionTitle, table, td, th } from "../../../../ui.js";
import {
  addPrescriptionItemAction,
  removePrescriptionItemAction,
  saveConsultationAction,
  signAndCompleteAction,
  startConsultationAction,
} from "./actions.js";

export const dynamic = "force-dynamic";

export default async function ConsultationPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string; appointmentId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId, appointmentId } = await params;
  const ctx = await requireOrgContext(orgId);
  const { error } = await searchParams;

  const [appointment, consultation] = await Promise.all([
    getAppointment(ctx, appointmentId),
    getConsultation(ctx, appointmentId),
  ]);

  const signed = !!consultation?.signedAt;
  const canWrite =
    (ctx.org!.role === "DOCTOR") || ctx.org!.role === "CLINIC_ADMIN"; // service enforces the real rule
  const items = consultation?.prescriptions.flatMap((p) => p.items) ?? [];

  return (
    <div>
      <SectionTitle>
        Consultation — {appointment.patient.firstName} {appointment.patient.lastName} ·{" "}
        {new Date(appointment.scheduledStart).toLocaleString([], {
          month: "short",
          day: "numeric",
          hour: "2-digit",
          minute: "2-digit",
        })}
      </SectionTitle>
      <ErrorNote message={error} />
      <div style={{ marginBottom: 16 }}>
        <Badge tone={appointment.status === "COMPLETED" ? "ok" : "coral"}>{appointment.status}</Badge>
        {signed && (
          <span style={{ marginLeft: 8 }}>
            <Badge tone="muted">Signed</Badge>
          </span>
        )}
      </div>

      {["CHECKED_IN", "WAITING"].includes(appointment.status) && canWrite && (
        <Card style={{ marginBottom: 20, maxWidth: 420 }}>
          <p style={{ marginTop: 0, fontSize: 14 }}>This appointment hasn&rsquo;t started yet.</p>
          <form action={startConsultationAction.bind(null, orgId, appointmentId)}>
            <Button>Start consultation</Button>
          </form>
        </Card>
      )}

      <Card style={{ marginBottom: 20, maxWidth: 640 }}>
        <SectionTitle>Notes</SectionTitle>
        <form action={saveConsultationAction.bind(null, orgId, appointmentId)}>
          <TextArea label="Subjective (patient-reported)" name="subjective" defaultValue={consultation?.subjective} disabled={signed} />
          <TextArea label="Objective (exam findings)" name="objective" defaultValue={consultation?.objective} disabled={signed} />
          <TextArea label="Assessment" name="assessment" defaultValue={consultation?.assessment} disabled={signed} />
          <TextArea label="Plan" name="plan" defaultValue={consultation?.plan} disabled={signed} />
          <Field
            label="Follow-up date"
            name="followUpDate"
            type="date"
            defaultValue={consultation?.followUpDate ? new Date(consultation.followUpDate).toISOString().slice(0, 10) : undefined}
          />
          <TextArea label="Tests advised" name="testsAdvised" defaultValue={consultation?.testsAdvised ?? undefined} disabled={signed} />
          <TextArea label="Instructions" name="instructions" defaultValue={consultation?.instructions ?? undefined} disabled={signed} />
          {!signed && canWrite && (
            <div style={{ marginTop: 8 }}>
              <Button variant="ghost">Save notes</Button>
            </div>
          )}
        </form>
      </Card>

      <Card style={{ marginBottom: 20, maxWidth: 640 }}>
        <SectionTitle>Prescription</SectionTitle>
        {items.length === 0 ? (
          <EmptyState>No medicines added yet.</EmptyState>
        ) : (
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>Drug</th>
                <th style={th}>Dosage</th>
                <th style={th}>Frequency</th>
                <th style={th}>Days</th>
                <th style={th} />
              </tr>
            </thead>
            <tbody>
              {items.map((it) => (
                <tr key={it.id}>
                  <td style={td}>
                    {it.drugName} {it.strength ?? ""}
                  </td>
                  <td style={td}>{it.dosage ?? "—"}</td>
                  <td style={td}>{it.frequency ?? "—"}</td>
                  <td style={td}>{it.durationDays ?? "—"}</td>
                  <td style={td}>
                    {!signed && canWrite && (
                      <form action={removePrescriptionItemAction.bind(null, orgId, appointmentId, it.id)}>
                        <Button variant="danger">Remove</Button>
                      </form>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}

        {!signed && canWrite && (
          <form action={addPrescriptionItemAction.bind(null, orgId, appointmentId)} style={{ marginTop: 14 }}>
            <div style={{ display: "flex", gap: 10, flexWrap: "wrap" }}>
              <div style={{ flex: "1 1 160px" }}>
                <Field label="Drug name" name="drugName" required />
              </div>
              <div style={{ flex: "1 1 100px" }}>
                <Field label="Strength" name="strength" placeholder="500mg" />
              </div>
              <div style={{ flex: "1 1 120px" }}>
                <Field label="Dosage" name="dosage" placeholder="1 tablet" />
              </div>
              <div style={{ flex: "1 1 140px" }}>
                <Field label="Frequency" name="frequency" placeholder="Twice daily" />
              </div>
              <div style={{ flex: "1 1 90px" }}>
                <Field label="Days" name="durationDays" type="number" />
              </div>
            </div>
            <Field label="Instructions" name="instructions" placeholder="Optional" />
            <Button variant="ghost">Add medicine</Button>
          </form>
        )}
      </Card>

      {!signed && canWrite && appointment.status === "IN_CONSULTATION" && (
        <form action={signAndCompleteAction.bind(null, orgId, appointmentId)}>
          <Button>Sign &amp; complete</Button>
        </form>
      )}
    </div>
  );
}

function TextArea({
  label,
  name,
  defaultValue,
  disabled,
}: {
  label: string;
  name: string;
  defaultValue?: string | null;
  disabled?: boolean;
}) {
  return (
    <label style={{ display: "block", marginBottom: 12 }}>
      <div style={{ fontSize: 12, fontWeight: 700, color: "var(--ink-muted)", marginBottom: 4 }}>
        {label}
      </div>
      <textarea
        name={name}
        defaultValue={defaultValue ?? ""}
        disabled={disabled}
        rows={2}
        style={{
          width: "100%",
          padding: "9px 12px",
          borderRadius: 10,
          border: "1px solid var(--border)",
          background: disabled ? "var(--border)" : "var(--surface)",
          color: "var(--ink)",
          fontSize: 14,
          fontFamily: "inherit",
          resize: "vertical",
        }}
      />
    </label>
  );
}
