import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { db } from "@/lib/db.js";
import { getAppointment } from "@/modules/appointments/service.js";
import { hasFamilyAccess } from "@/modules/family/service.js";
import { Badge, Button, Card, CardSubtitle, CardTitle, LinkButton, Notice, statusLabel, statusTone } from "@/components/ui/index.js";
import { ConfirmSubmit } from "@/components/confirm-submit.js";
import {
  cancelAppointmentAction,
  checkInAppointmentAction,
  confirmAppointmentAction,
  noShowAppointmentAction,
} from "../actions.js";

export const dynamic = "force-dynamic";

export default async function AppointmentDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string; appointmentId: string }>;
  searchParams: Promise<{ error?: string; justBooked?: string }>;
}) {
  const { orgId, appointmentId } = await params;
  const ctx = await requireOrgContext(orgId);
  const role = ctx.org!.role;
  const { error, justBooked } = await searchParams;

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
  // A guardian managing a dependent's appointments (PRODUCT_EVOLUTION_PLAN.md
  // Phase 11) gets the same reschedule/cancel affordances as the patient
  // themself — the service layer is the real authority either way.
  const canManageAsFamily =
    role === "PATIENT" && !isMyPatient && (await hasFamilyAccess(ctx, appt.patient.id, "MANAGE_APPOINTMENTS"));
  const canActAsPatient = isMyPatient || canManageAsFamily;
  const isMyAppointmentAsDoctor = role === "DOCTOR" && appt.doctorId === myDoctorId;

  // Self-service cancellation closes this many hours before the start
  // (enforced by the service; surfaced here so patients learn the rule from
  // the UI instead of from an error).
  const settings =
    isStaff || canActAsPatient
      ? await db.clinicSettings.findUnique({
          where: { organizationId: orgId },
          select: { cancellationWindowHours: true },
        })
      : null;
  const cancelWindowHours = settings?.cancellationWindowHours ?? null;

  return (
    <div className="flex max-w-2xl flex-col gap-6">
      <Link href={`/dashboard/${orgId}/appointments`} className="text-sm text-indigo no-underline">
        ← All appointments
      </Link>

      {justBooked ? <Notice tone="ok">Your appointment is booked.</Notice> : null}
      {error ? <Notice tone="down">{error}</Notice> : null}

      <Card>
        <div className="flex items-start justify-between gap-4">
          <div>
            <CardSubtitle>Appointment</CardSubtitle>
            <CardTitle className="mt-1 text-lg">{appt.doctor.displayName}</CardTitle>
            <p className="mt-1 text-sm text-ink-muted">
              {appt.patient.firstName} {appt.patient.lastName}
            </p>
          </div>
          <Badge tone={statusTone(appt.status)}>{statusLabel(appt.status)}</Badge>
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

        {/* Ownership chain (request §27/§28): which branch, what kind of
            visit — shown to every role that can read the appointment. */}
        <div className="mt-2 flex flex-wrap items-center gap-2 text-[12.5px] text-ink-muted">
          {appt.location ? <span>📍 {appt.location.name}{appt.location.city ? ` — ${appt.location.city}` : ""}</span> : null}
          {appt.appointmentType ? <span>· {appt.appointmentType.name} ({appt.appointmentType.durationMinutes} min)</span> : null}
        </div>

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
              <LinkButton variant="secondary" href={`/dashboard/${orgId}/appointments/${appt.id}/consultation`}>
                Consultation notes
              </LinkButton>
            )}
          {["REQUESTED", "CONFIRMED"].includes(appt.status) && (isStaff || canActAsPatient) && (
            <LinkButton variant="secondary" href={`/dashboard/${orgId}/appointments/${appt.id}/reschedule`}>
              Reschedule
            </LinkButton>
          )}
          {["REQUESTED", "CONFIRMED", "CHECKED_IN", "WAITING"].includes(appt.status) && (isStaff || canActAsPatient) && (
            <div>
              <form action={cancelAppointmentAction.bind(null, orgId, appt.id)}>
                <input type="hidden" name="reason" value={isStaff ? "Cancelled by staff" : "Cancelled by patient"} />
                <ConfirmSubmit
                  label="Cancel appointment"
                  variant="danger"
                  confirmTitle="Cancel this appointment?"
                  confirmMessage={
                    isStaff
                      ? "The patient will be notified, and the time slot is released for others."
                      : "The clinic will be notified, and the time slot is released for others."
                  }
                />
              </form>
              {canActAsPatient && !isStaff && cancelWindowHours != null ? (
                <p className="mt-2 max-w-xs text-[11.5px] text-ink-faint">
                  You can cancel yourself up to {cancelWindowHours} {cancelWindowHours === 1 ? "hour" : "hours"} before the
                  appointment — inside that window, contact the clinic.
                </p>
              ) : null}
            </div>
          )}
        </div>
      </Card>

      {justBooked ? (
        <div className="flex flex-wrap gap-2">
          <LinkButton href={`/dashboard/${orgId}`}>Go to dashboard</LinkButton>
          <LinkButton variant="secondary" href="/doctors">
            Book another appointment
          </LinkButton>
        </div>
      ) : null}

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
