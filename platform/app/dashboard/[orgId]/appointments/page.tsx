import { requireOrgContext } from "@/lib/web-context.js";
import { db } from "@/lib/db.js";
import { listAppointments } from "@/modules/appointments/service.js";
import { listDoctors } from "@/modules/doctors/service.js";
import { listPatients } from "@/modules/patients/service.js";
import { Badge, Button, Card, EmptyState, ErrorNote, SectionTitle, table, td, th } from "../../ui.js";
import { BookForm } from "./BookForm.js";
import {
  bookAppointmentAction,
  cancelAppointmentAction,
  checkInAppointmentAction,
  completeAppointmentAction,
  confirmAppointmentAction,
  noShowAppointmentAction,
  startAppointmentAction,
} from "./actions.js";

export const dynamic = "force-dynamic";

const STATUS_TONE: Record<string, "indigo" | "coral" | "ok" | "muted"> = {
  REQUESTED: "coral",
  CONFIRMED: "indigo",
  CHECKED_IN: "indigo",
  WAITING: "indigo",
  IN_CONSULTATION: "coral",
  COMPLETED: "ok",
  CANCELLED: "muted",
  NO_SHOW: "muted",
  RESCHEDULED: "muted",
};

export default async function AppointmentsPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const role = ctx.org!.role;
  const { error } = await searchParams;

  const doctors = await listDoctors(ctx);
  const patients =
    role === "RECEPTIONIST" || role === "CLINIC_ADMIN" || role === "DOCTOR"
      ? (await listPatients(ctx, { limit: 100 })).data
      : undefined;

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
    <div>
      <SectionTitle>Appointments</SectionTitle>
      <ErrorNote message={error} />

      <Card style={{ marginBottom: 20 }}>
        {appointments.length === 0 ? (
          <EmptyState>No appointments yet.</EmptyState>
        ) : (
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>When</th>
                <th style={th}>Patient</th>
                <th style={th}>Doctor</th>
                <th style={th}>Status</th>
                <th style={th}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {appointments.map((a) => {
                const isMine = myDoctorId && a.doctorId === myDoctorId;
                return (
                  <tr key={a.id}>
                    <td style={td}>
                      {new Date(a.scheduledStart).toLocaleString([], {
                        month: "short",
                        day: "numeric",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </td>
                    <td style={td}>
                      {a.patient.firstName} {a.patient.lastName}
                    </td>
                    <td style={td}>{a.doctor.displayName}</td>
                    <td style={td}>
                      <Badge tone={STATUS_TONE[a.status] ?? "muted"}>{a.status}</Badge>
                    </td>
                    <td style={td}>
                      <div style={{ display: "flex", gap: 6, flexWrap: "wrap" }}>
                        {isStaff && a.status === "REQUESTED" && (
                          <form action={confirmAppointmentAction.bind(null, orgId, a.id)}>
                            <Button variant="ghost">Confirm</Button>
                          </form>
                        )}
                        {isStaff && a.status === "CONFIRMED" && (
                          <>
                            <form action={checkInAppointmentAction.bind(null, orgId, a.id)}>
                              <Button variant="ghost">Check in</Button>
                            </form>
                            <form action={noShowAppointmentAction.bind(null, orgId, a.id)}>
                              <Button variant="ghost">No-show</Button>
                            </form>
                          </>
                        )}
                        {role === "DOCTOR" && isMine && ["CHECKED_IN", "WAITING"].includes(a.status) && (
                          <form action={startAppointmentAction.bind(null, orgId, a.id)}>
                            <Button variant="ghost">Start</Button>
                          </form>
                        )}
                        {role === "DOCTOR" && isMine && a.status === "IN_CONSULTATION" && (
                          <form action={completeAppointmentAction.bind(null, orgId, a.id)}>
                            <Button variant="ghost">Complete</Button>
                          </form>
                        )}
                        {["REQUESTED", "CONFIRMED", "CHECKED_IN", "WAITING"].includes(a.status) && (
                          <form action={cancelAppointmentAction.bind(null, orgId, a.id)}>
                            <input type="hidden" name="reason" value="Cancelled from dashboard" />
                            <Button variant="danger">Cancel</Button>
                          </form>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </Card>

      {doctors.length > 0 ? (
        <Card style={{ maxWidth: 420 }}>
          <SectionTitle>Book an appointment</SectionTitle>
          <BookForm
            orgId={orgId}
            doctors={doctors}
            patients={patients}
            action={bookAppointmentAction.bind(null, orgId)}
          />
        </Card>
      ) : (
        <EmptyState>Add a doctor with availability before booking appointments.</EmptyState>
      )}
    </div>
  );
}
