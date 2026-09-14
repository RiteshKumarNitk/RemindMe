import { requireOrgContext } from "@/lib/web-context.js";
import { getAppointment } from "@/modules/appointments/service.js";
import { Card, ErrorNote, SectionTitle } from "../../../../ui.js";
import { BookForm } from "../../BookForm.js";
import { rescheduleAppointmentAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function ReschedulePage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string; appointmentId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId, appointmentId } = await params;
  const ctx = await requireOrgContext(orgId);
  const { error } = await searchParams;
  const appointment = await getAppointment(ctx, appointmentId);

  return (
    <div>
      <SectionTitle>
        Reschedule — {appointment.patient.firstName} {appointment.patient.lastName} with{" "}
        {appointment.doctor.displayName}
      </SectionTitle>
      <Card style={{ maxWidth: 420 }}>
        <ErrorNote message={error} />
        <p style={{ marginTop: 0, fontSize: 13, color: "var(--ink-muted)" }}>
          Currently{" "}
          {new Date(appointment.scheduledStart).toLocaleString([], {
            weekday: "short",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          })}
          . Pick a new time below.
        </p>
        <BookForm
          orgId={orgId}
          doctors={[{ id: appointment.doctorId, displayName: appointment.doctor.displayName }]}
          action={rescheduleAppointmentAction.bind(null, orgId, appointmentId)}
        />
      </Card>
    </div>
  );
}
