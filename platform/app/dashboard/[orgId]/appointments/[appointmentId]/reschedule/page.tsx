import { requireOrgContext } from "@/lib/web-context.js";
import { getAppointment } from "@/modules/appointments/service.js";
import { Card, CardSubtitle, InitialsAvatar, Notice } from "@/components/ui/index.js";
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
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <InitialsAvatar name={`${appointment.patient.firstName} ${appointment.patient.lastName}`} />
        <div>
          <h1 className="font-display text-2xl font-bold text-ink">Reschedule appointment</h1>
          <p className="text-sm text-ink-muted">
            {appointment.patient.firstName} {appointment.patient.lastName} with {appointment.doctor.displayName}
          </p>
        </div>
      </div>

      {error ? <Notice tone="down">{error}</Notice> : null}

      <Card className="max-w-2xl">
        <CardSubtitle>
          Currently{" "}
          {new Date(appointment.scheduledStart).toLocaleString([], {
            weekday: "short",
            month: "short",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          })}
          . Pick a new time below.
        </CardSubtitle>
        <div className="mt-4">
          <BookForm
            orgId={orgId}
            doctors={[{ id: appointment.doctorId, displayName: appointment.doctor.displayName }]}
            action={rescheduleAppointmentAction.bind(null, orgId, appointmentId)}
            submitLabel="Confirm reschedule"
          />
        </div>
      </Card>
    </div>
  );
}
