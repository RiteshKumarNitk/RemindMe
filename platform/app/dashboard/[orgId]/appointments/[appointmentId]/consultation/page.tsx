import { requireOrgContext } from "@/lib/web-context.js";
import { getAppointment } from "@/modules/appointments/service.js";
import { getConsultation } from "@/modules/consultations/service.js";
import { Badge, Button, Card, CardSubtitle, EmptyState, Field, Input, Notice, Textarea } from "@/components/ui/index.js";
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
    <div className="flex flex-col gap-7">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Consultation</h1>
        <p className="mt-1 text-sm text-ink-muted">
          {appointment.patient.firstName} {appointment.patient.lastName} ·{" "}
          {new Date(appointment.scheduledStart).toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
        </p>
        <div className="mt-2 flex gap-2">
          <Badge tone={appointment.status === "COMPLETED" ? "ok" : "coral"}>{appointment.status}</Badge>
          {signed ? <Badge tone="neutral">Signed</Badge> : null}
        </div>
      </div>

      {error ? <Notice tone="down">{error}</Notice> : null}

      {["CHECKED_IN", "WAITING"].includes(appointment.status) && canWrite && (
        <Card className="max-w-md">
          <p className="mb-4 text-sm text-ink">This appointment hasn&rsquo;t started yet.</p>
          <form action={startConsultationAction.bind(null, orgId, appointmentId)}>
            <Button>Start consultation</Button>
          </form>
        </Card>
      )}

      <Card className="max-w-2xl">
        <CardSubtitle>Notes</CardSubtitle>
        <form action={saveConsultationAction.bind(null, orgId, appointmentId)} className="mt-4 flex flex-col gap-4">
          <Field label="Subjective (patient-reported)">
            <Textarea name="subjective" defaultValue={consultation?.subjective ?? ""} disabled={signed} className="w-full" />
          </Field>
          <Field label="Objective (exam findings)">
            <Textarea name="objective" defaultValue={consultation?.objective ?? ""} disabled={signed} className="w-full" />
          </Field>
          <Field label="Assessment">
            <Textarea name="assessment" defaultValue={consultation?.assessment ?? ""} disabled={signed} className="w-full" />
          </Field>
          <Field label="Plan">
            <Textarea name="plan" defaultValue={consultation?.plan ?? ""} disabled={signed} className="w-full" />
          </Field>
          <Field label="Follow-up date">
            <Input
              name="followUpDate"
              type="date"
              defaultValue={consultation?.followUpDate ? new Date(consultation.followUpDate).toISOString().slice(0, 10) : undefined}
              disabled={signed}
              className="w-full"
            />
          </Field>
          <Field label="Tests advised">
            <Textarea name="testsAdvised" defaultValue={consultation?.testsAdvised ?? ""} disabled={signed} className="w-full" />
          </Field>
          <Field label="Instructions">
            <Textarea name="instructions" defaultValue={consultation?.instructions ?? ""} disabled={signed} className="w-full" />
          </Field>
          {!signed && canWrite && (
            <Button variant="ghost" className="self-start">
              Save notes
            </Button>
          )}
        </form>
      </Card>

      <Card className="max-w-2xl">
        <CardSubtitle>Prescription</CardSubtitle>
        {items.length === 0 ? (
          <div className="mt-4">
            <EmptyState title="No medicines added yet." />
          </div>
        ) : (
          <div className="mt-4 flex flex-col">
            {items.map((it, i) => (
              <div
                key={it.id}
                className={`flex flex-wrap items-center gap-3 py-2.5 ${i < items.length - 1 ? "border-b border-border" : ""}`}
              >
                <div className="min-w-0 flex-1">
                  <div className="text-[13.5px] font-semibold text-ink">
                    {it.drugName} {it.strength ?? ""}
                  </div>
                  <div className="text-[11.5px] text-ink-muted">
                    {it.dosage ?? "—"} · {it.frequency ?? "—"} {it.durationDays ? `· ${it.durationDays}d` : ""}
                  </div>
                </div>
                {!signed && canWrite && (
                  <form action={removePrescriptionItemAction.bind(null, orgId, appointmentId, it.id)}>
                    <Button variant="danger" size="sm">
                      Remove
                    </Button>
                  </form>
                )}
              </div>
            ))}
          </div>
        )}

        {!signed && canWrite && (
          <form action={addPrescriptionItemAction.bind(null, orgId, appointmentId)} className="mt-5 flex flex-col gap-4 border-t border-border pt-5">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-5">
              <Field label="Drug name">
                <Input name="drugName" required className="w-full" />
              </Field>
              <Field label="Strength">
                <Input name="strength" placeholder="500mg" className="w-full" />
              </Field>
              <Field label="Dosage">
                <Input name="dosage" placeholder="1 tablet" className="w-full" />
              </Field>
              <Field label="Frequency">
                <Input name="frequency" placeholder="Twice daily" className="w-full" />
              </Field>
              <Field label="Days">
                <Input name="durationDays" type="number" className="w-full" />
              </Field>
            </div>
            <Field label="Instructions" hint="Optional">
              <Input name="instructions" className="w-full" />
            </Field>
            <Button variant="ghost" className="self-start">
              Add medicine
            </Button>
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
