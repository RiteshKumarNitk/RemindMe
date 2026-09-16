import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { db } from "@/lib/db.js";
import { getAppointment } from "@/modules/appointments/service.js";
import { Badge, Button, Card, CardSubtitle, CardTitle } from "@/components/ui/index.js";
import {
  cancelAppointmentAction,
  checkInAppointmentAction,
  confirmAppointmentAction,
  noShowAppointmentAction,
} from "../actions.js";

export const dynamic = "force-dynamic";

const STATUS_TONE: Record<string, "indigo" | "ok" | "down" | "neutral"> = {
  REQUESTED: "neutral",
  CONFIRMED: "indigo",
  CHECKED_IN: "indigo",
  WAITING: "indigo",
  IN_CONSULTATION: "indigo",
  COMPLETED: "ok",
  CANCELLED: "down",
  NO_SHOW: "down",
  RESCHEDULED: "neutral",
};

export default async function AppointmentDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string; appointmentId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId, appointmentId } = await params;
  const ctx = await requireOrgContext(orgId);
  const role = ctx.org!.role;
  const { error } = await searchParams;

  const appt = await getAppointment(ctx, appointmentId);

  let myDoctorId: string | null = null;
  if (role === "DOCTOR") {
    const mine = await db.doctorProfile.findFirst({
      where: { organizationId: orgId, userId: ctx.userId },
      select: { id: true },
    });
    myDoctorId = mine?.id ?? null;
  }
  const isStaff = role === "RECEPTIONIST" || role === "CLINIC_ADMIN";
  const isMyPatient = role === "PATIENT" && appt.patient.ownerUserId === ctx.userId;
  const isMyAppointmentAsDoctor = role === "DOCTOR" && appt.doctorId === myDoctorId;

  return (
    <div className="flex max-w-2xl flex-col gap-6">
      <Link href={`/dashboard/${orgId}/appointments`} className="text-sm text-indigo no-underline">
        ← All appointments
      </Link>

      {error ? (
        <div className="rounded-control border border-down/30 bg-down/5 px-4 py-3 text-sm text-down">{error}</div>
      ) : null}

      <Card>
        <div className="flex items-start justify-between gap-4">
          <div>
            <CardSubtitle>Appointment</CardSubtitle>
            <CardTitle className="mt-1 text-lg">{appt.doctor.displayName}</CardTitle>
            <p className="mt-1 text-sm text-ink-muted">
              {appt.patient.firstName} {appt.patient.lastName}
            </p>
          </div>
          <Badge tone={STATUS_TONE[appt.status] ?? "neutral"}>{appt.status}</Badge>
        </div>

        <p className="mt-4 text-sm font-medium text-ink">
          {new Date(appt.scheduledStart).toLocaleString(undefined, {
            weekday: "long",
            month: "long",
            day: "numeric",
            hour: "2-digit",
            minute: "2-digit",
          })}
        </p>

        {appt.queueEntry ? (
          <div className="mt-2">
            <Badge tone="ok">Token {appt.queueEntry.tokenNumber}</Badge>
          </div>
        ) : null}

        {appt.reason ? (
          <p className="mt-4 text-sm text-ink">
            <span className="text-ink-muted">Reason: </span>
            {appt.reason}
          </p>
        ) : null}

        <div className="mt-6 flex flex-wrap gap-2">
          {isStaff && appt.status === "REQUESTED" && (
            <form action={confirmAppointmentAction.bind(null, orgId, appt.id)}>
              <Button variant="secondary">Confirm</Button>
            </form>
          )}
          {isStaff && appt.status === "CONFIRMED" && (
            <>
              <form action={checkInAppointmentAction.bind(null, orgId, appt.id)}>
                <Button variant="secondary">Check in</Button>
              </form>
              <form action={noShowAppointmentAction.bind(null, orgId, appt.id)}>
                <Button variant="secondary">No-show</Button>
              </form>
            </>
          )}
          {(isStaff || isMyAppointmentAsDoctor) &&
            ["CHECKED_IN", "WAITING", "IN_CONSULTATION", "COMPLETED"].includes(appt.status) && (
              <Link href={`/dashboard/${orgId}/appointments/${appt.id}/consultation`}>
                <Button variant="secondary">Consultation notes</Button>
              </Link>
            )}
          {["REQUESTED", "CONFIRMED"].includes(appt.status) && (isStaff || isMyPatient) && (
            <Link href={`/dashboard/${orgId}/appointments/${appt.id}/reschedule`}>
              <Button variant="secondary">Reschedule</Button>
            </Link>
          )}
          {["REQUESTED", "CONFIRMED", "CHECKED_IN", "WAITING"].includes(appt.status) && (isStaff || isMyPatient) && (
            <form action={cancelAppointmentAction.bind(null, orgId, appt.id)}>
              <input type="hidden" name="reason" value="Cancelled by patient" />
              <Button variant="danger">Cancel</Button>
            </form>
          )}
        </div>
      </Card>

      {appt.events.length > 0 ? (
        <Card>
          <CardSubtitle>History</CardSubtitle>
          <ul className="mt-2 flex flex-col gap-1.5 text-sm text-ink-muted">
            {appt.events.map((e) => (
              <li key={e.id}>
                {new Date(e.at).toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
                {" — "}
                {e.toStatus}
              </li>
            ))}
          </ul>
        </Card>
      ) : null}
    </div>
  );
}
