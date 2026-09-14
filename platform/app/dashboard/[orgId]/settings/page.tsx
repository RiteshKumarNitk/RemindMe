import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { getSettings, listLocations } from "@/modules/clinics/service.js";
import { listAppointmentTypes } from "@/modules/appointments/service.js";
import { Button, Card, EmptyState, ErrorNote, Field, SectionTitle, table, td, th } from "../../ui.js";
import { addAppointmentTypeAction, addLocationAction, saveSettingsAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function SettingsPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);
  const { error } = await searchParams;
  const [settings, locations, types] = await Promise.all([
    getSettings(ctx),
    listLocations(ctx),
    listAppointmentTypes(ctx),
  ]);

  return (
    <div>
      <SectionTitle>Clinic settings</SectionTitle>
      <Card style={{ marginBottom: 20, maxWidth: 480 }}>
        <ErrorNote message={error} />
        <form action={saveSettingsAction.bind(null, orgId)}>
          <label style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 14, fontSize: 14 }}>
            <input type="checkbox" name="allowPatientSelfBooking" defaultChecked={settings.allowPatientSelfBooking} />
            Allow patients to book their own appointments
          </label>
          <Field
            label="Booking lead time (minutes)"
            name="bookingLeadTimeMinutes"
            type="number"
            defaultValue={String(settings.bookingLeadTimeMinutes)}
          />
          <Field
            label="Cancellation window (hours)"
            name="cancellationWindowHours"
            type="number"
            defaultValue={String(settings.cancellationWindowHours)}
          />
          <Field
            label="Max advance booking (days)"
            name="maxAdvanceBookingDays"
            type="number"
            defaultValue={String(settings.maxAdvanceBookingDays)}
          />
          <Field
            label="Default appointment length (minutes)"
            name="defaultAppointmentDurationMin"
            type="number"
            defaultValue={String(settings.defaultAppointmentDurationMin)}
          />
          <div style={{ marginTop: 8 }}>
            <Button>Save settings</Button>
          </div>
        </form>
      </Card>

      <SectionTitle>Locations</SectionTitle>
      <Card style={{ marginBottom: 20 }}>
        {locations.length === 0 ? (
          <EmptyState>No locations yet.</EmptyState>
        ) : (
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>Name</th>
                <th style={th}>City</th>
              </tr>
            </thead>
            <tbody>
              {locations.map((l) => (
                <tr key={l.id}>
                  <td style={td}>{l.name}</td>
                  <td style={td}>{l.city ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <form action={addLocationAction.bind(null, orgId)} style={{ marginTop: 14, maxWidth: 360 }}>
          <Field label="Location name" name="name" required placeholder="Main Branch" />
          <Field label="City" name="city" />
          <Button variant="ghost">Add location</Button>
        </form>
      </Card>

      <SectionTitle>Appointment types</SectionTitle>
      <Card>
        {types.length === 0 ? (
          <EmptyState>No appointment types yet — booking uses the clinic default duration.</EmptyState>
        ) : (
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>Name</th>
                <th style={th}>Duration (min)</th>
              </tr>
            </thead>
            <tbody>
              {types.map((t) => (
                <tr key={t.id}>
                  <td style={td}>{t.name}</td>
                  <td style={td}>{t.durationMinutes}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
        <form action={addAppointmentTypeAction.bind(null, orgId)} style={{ marginTop: 14, maxWidth: 360 }}>
          <Field label="Type name" name="name" required placeholder="Consultation" />
          <Field label="Duration (min)" name="durationMinutes" type="number" defaultValue="15" />
          <Button variant="ghost">Add type</Button>
        </form>
      </Card>
    </div>
  );
}
