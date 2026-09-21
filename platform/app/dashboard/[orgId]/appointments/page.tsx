import { requireOrgContext } from "@/lib/web-context.js";
import { db } from "@/lib/db.js";
import { listAppointments } from "@/modules/appointments/service.js";
import { listDoctors } from "@/modules/doctors/service.js";
import { listPatients } from "@/modules/patients/service.js";
import { listMyAccess } from "@/modules/family/service.js";
import { Badge, Button, Card, CardSubtitle, EmptyState, InitialsAvatar, LinkButton, Notice } from "@/components/ui/index.js";
import { BookForm } from "./BookForm.js";
import {
  bookAppointmentAction,
  cancelAppointmentAction,
  checkInAppointmentAction,
  confirmAppointmentAction,
  noShowAppointmentAction,
} from "./actions.js";

export const dynamic = "force-dynamic";

const STATUS_TONE: Record<string, "indigo" | "coral" | "ok" | "neutral"> = {
  REQUESTED: "coral",
  CONFIRMED: "indigo",
  CHECKED_IN: "indigo",
  WAITING: "indigo",
  IN_CONSULTATION: "coral",
  COMPLETED: "ok",
  CANCELLED: "neutral",
  NO_SHOW: "neutral",
  RESCHEDULED: "neutral",
};

export default async function AppointmentsPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string; booked?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const role = ctx.org!.role;
  const { error, booked } = await searchParams;

  const doctors = await listDoctors(ctx);
  let patients: Array<{ id: string; firstName: string; lastName: string }> | undefined;
  if (role === "RECEPTIONIST" || role === "CLINIC_ADMIN" || role === "DOCTOR") {
    patients = (await listPatients(ctx, { limit: 100 })).data;
  } else if (role === "PATIENT") {
    // A patient books for themselves by default; if they also manage any
    // dependents' appointments (family access grant), offer a picker
    // instead of silently assuming "myself" (PRODUCT_EVOLUTION_PLAN.md
    // Phase 11).
    const [own, myAccess] = await Promise.all([
      db.patient.findFirst({
        where: { organizationId: orgId, ownerUserId: ctx.userId },
        select: { id: true, firstName: true, lastName: true },
      }),
      listMyAccess(ctx),
    ]);
    const dependents = myAccess.data
      .filter((g) => g.permissions.includes("MANAGE_APPOINTMENTS"))
      .map((g) => g.patient);
    if (dependents.length > 0) {
      patients = own ? [{ ...own, firstName: `${own.firstName} (Myself)` }, ...dependents] : dependents;
    }
  }

  let myDoctorId: string | null = null;
  if (role === "DOCTOR") {
    const mine = await db.doctorProfile.findFirst({
      where: { organizationId: orgId, userId: ctx.userId },
      select: { id: true },
    });
    myDoctorId = mine?.id ?? null;
  }

  const { data: appointments } = await listAppointments(ctx, {
    limit: 100,
    ...(myDoctorId ? { doctorId: myDoctorId } : {}),
  });

  const isStaff = role === "RECEPTIONIST" || role === "CLINIC_ADMIN";

  return (
    <div className="flex flex-col gap-7">
      <h1 className="font-display text-2xl font-bold text-ink">Appointments</h1>

      {booked ? <Notice tone="ok">Your appointment is booked.</Notice> : null}
      {error ? <Notice tone="down">{error}</Notice> : null}

      {appointments.length === 0 ? (
        <Card>
          <EmptyState title="No appointments yet." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {appointments.map((a) => {
            const isMine = myDoctorId && a.doctorId === myDoctorId;
            return (
              <Card key={a.id} className="p-4!">
                <div className="flex items-center gap-3">
                  <InitialsAvatar name={`${a.patient.firstName} ${a.patient.lastName}`} />
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[13.5px] font-semibold text-ink">
                      {a.patient.firstName} {a.patient.lastName}
                    </div>
                    <div className="truncate text-[11.5px] text-ink-muted">
                      {a.doctor.displayName} ·{" "}
                      {new Date(a.scheduledStart).toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
                    </div>
                  </div>
                  <Badge tone={STATUS_TONE[a.status] ?? "neutral"}>{a.status}</Badge>
                </div>

                <div className="mt-3 flex flex-wrap gap-2 border-t border-border pt-3">
                  <LinkButton variant="ghost" size="sm" href={`/dashboard/${orgId}/appointments/${a.id}`}>
                    View
                  </LinkButton>
                  {isStaff && a.status === "REQUESTED" && (
                    <form action={confirmAppointmentAction.bind(null, orgId, a.id)}>
                      <Button variant="ghost" size="sm">
                        Confirm
                      </Button>
                    </form>
                  )}
                  {isStaff && a.status === "CONFIRMED" && (
                    <>
                      <form action={checkInAppointmentAction.bind(null, orgId, a.id)}>
                        <Button variant="ghost" size="sm">
                          Check in
                        </Button>
                      </form>
                      <form action={noShowAppointmentAction.bind(null, orgId, a.id)}>
                        <Button variant="ghost" size="sm">
                          No-show
                        </Button>
                      </form>
                    </>
                  )}
                  {(role === "CLINIC_ADMIN" || (role === "DOCTOR" && isMine)) &&
                    ["CHECKED_IN", "WAITING", "IN_CONSULTATION", "COMPLETED"].includes(a.status) && (
                      <LinkButton variant="ghost" size="sm" href={`/dashboard/${orgId}/appointments/${a.id}/consultation`}>
                        Notes
                      </LinkButton>
                    )}
                  {["REQUESTED", "CONFIRMED"].includes(a.status) && (
                    <LinkButton variant="ghost" size="sm" href={`/dashboard/${orgId}/appointments/${a.id}/reschedule`}>
                      Reschedule
                    </LinkButton>
                  )}
                  {["REQUESTED", "CONFIRMED", "CHECKED_IN", "WAITING"].includes(a.status) && (
                    <form action={cancelAppointmentAction.bind(null, orgId, a.id)}>
                      <input type="hidden" name="reason" value="Cancelled from dashboard" />
                      <Button variant="danger" size="sm">
                        Cancel
                      </Button>
                    </form>
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {doctors.length > 0 ? (
        <Card>
          <CardSubtitle>Book an appointment</CardSubtitle>
          <div className="mt-3">
            <BookForm
              orgId={orgId}
              doctors={doctors}
              patients={patients}
              action={bookAppointmentAction.bind(null, orgId)}
            />
          </div>
        </Card>
      ) : (
        <EmptyState title="Add a doctor with availability before booking appointments." />
      )}
    </div>
  );
}
