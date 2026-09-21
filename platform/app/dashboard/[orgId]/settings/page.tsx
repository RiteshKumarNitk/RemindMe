import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { getSettings, listLocations } from "@/modules/clinics/service.js";
import { listAppointmentTypes } from "@/modules/appointments/service.js";
import { Button, Card, CardSubtitle, EmptyState, Field, Input, Notice } from "@/components/ui/index.js";
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
    <div className="flex flex-col gap-8">
      <h1 className="font-display text-2xl font-bold text-ink">Clinic settings</h1>

      {error ? <Notice tone="down">{error}</Notice> : null}

      <Card className="max-w-lg">
        <CardSubtitle>Booking rules</CardSubtitle>
        <form action={saveSettingsAction.bind(null, orgId)} className="mt-4 flex flex-col gap-4">
          <label className="flex items-center gap-2.5 text-sm text-ink">
            <input
              type="checkbox"
              name="allowPatientSelfBooking"
              defaultChecked={settings.allowPatientSelfBooking}
              className="h-4 w-4 accent-indigo"
            />
            Allow patients to book their own appointments
          </label>
          <div className="grid grid-cols-2 gap-4">
            <Field label="Booking lead time (minutes)">
              <Input name="bookingLeadTimeMinutes" type="number" defaultValue={String(settings.bookingLeadTimeMinutes)} className="w-full" />
            </Field>
            <Field label="Cancellation window (hours)">
              <Input name="cancellationWindowHours" type="number" defaultValue={String(settings.cancellationWindowHours)} className="w-full" />
            </Field>
            <Field label="Max advance booking (days)">
              <Input name="maxAdvanceBookingDays" type="number" defaultValue={String(settings.maxAdvanceBookingDays)} className="w-full" />
            </Field>
            <Field label="Default appointment length (min)">
              <Input
                name="defaultAppointmentDurationMin"
                type="number"
                defaultValue={String(settings.defaultAppointmentDurationMin)}
                className="w-full"
              />
            </Field>
          </div>
          <Button className="self-start">Save settings</Button>
        </form>
      </Card>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Locations</h2>
        <Card>
          {locations.length === 0 ? (
            <EmptyState title="No locations yet." />
          ) : (
            <div className="flex flex-col">
              {locations.map((l) => (
                <div key={l.id} className="flex items-center justify-between border-b border-border py-2.5 first:pt-0 last:border-0 last:pb-0">
                  <span className="text-[13.5px] font-semibold text-ink">{l.name}</span>
                  <span className="text-[12px] text-ink-muted">{l.city ?? "—"}</span>
                </div>
              ))}
            </div>
          )}
          <form action={addLocationAction.bind(null, orgId)} className="mt-4 flex max-w-sm flex-col gap-3">
            <Field label="Location name">
              <Input name="name" required placeholder="Main Branch" className="w-full" />
            </Field>
            <Field label="City">
              <Input name="city" className="w-full" />
            </Field>
            <Button variant="ghost" className="self-start">
              Add location
            </Button>
          </form>
        </Card>
      </div>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Appointment types</h2>
        <Card>
          {types.length === 0 ? (
            <EmptyState title="No appointment types yet." description="Booking uses the clinic default duration until you add one." />
          ) : (
            <div className="flex flex-col">
              {types.map((t) => (
                <div key={t.id} className="flex items-center justify-between border-b border-border py-2.5 first:pt-0 last:border-0 last:pb-0">
                  <span className="text-[13.5px] font-semibold text-ink">{t.name}</span>
                  <span className="font-mono text-[12px] text-ink-muted">{t.durationMinutes} min</span>
                </div>
              ))}
            </div>
          )}
          <form action={addAppointmentTypeAction.bind(null, orgId)} className="mt-4 flex max-w-sm flex-col gap-3">
            <Field label="Type name">
              <Input name="name" required placeholder="Consultation" className="w-full" />
            </Field>
            <Field label="Duration (min)">
              <Input name="durationMinutes" type="number" defaultValue="15" className="w-full" />
            </Field>
            <Button variant="ghost" className="self-start">
              Add type
            </Button>
          </form>
        </Card>
      </div>
    </div>
  );
}
