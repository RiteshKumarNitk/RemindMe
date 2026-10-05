import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { getSettings, listLocations } from "@/modules/clinics/service.js";
import { listAppointmentTypes } from "@/modules/appointments/service.js";
import { Button, Card, CardSubtitle, EmptyState, Field, Input, Notice } from "@/components/ui/index.js";
import { ConfirmSubmit } from "@/components/confirm-submit.js";
import {
  addAppointmentTypeAction,
  addLocationAction,
  deactivateLocationAction,
  saveSettingsAction,
  updateLocationAction,
} from "./actions.js";

export const dynamic = "force-dynamic";

export default async function SettingsPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string; saved?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);
  const { error, saved } = await searchParams;
  const [settings, locations, types] = await Promise.all([
    getSettings(ctx),
    listLocations(ctx),
    listAppointmentTypes(ctx),
  ]);

  return (
    <div className="flex flex-col gap-8">
      <h1 className="font-display text-2xl font-bold text-ink">Clinic settings</h1>

      {error ? <Notice tone="down">{error}</Notice> : null}
      {saved ? <Notice tone="ok">Settings saved.</Notice> : null}

      <Card className="max-w-lg">
        <CardSubtitle>Booking rules</CardSubtitle>
        <form action={saveSettingsAction.bind(null, orgId)} className="mt-4 flex flex-col gap-4">
          <div className="flex flex-col gap-1">
            <label className="flex items-center gap-2.5 text-sm text-ink">
              <input
                type="checkbox"
                name="allowPatientSelfBooking"
                defaultChecked={settings.allowPatientSelfBooking}
                className="h-4 w-4 accent-indigo"
              />
              Allow patients to book their own appointments
            </label>
            <p className="text-xs text-ink-muted">
              When off, patients who try to book themselves from the public site or app are
              refused — reception can still book for anyone.
            </p>
          </div>
          <div className="grid grid-cols-2 gap-4">
            <Field
              label="Booking lead time (minutes)"
              hint="Slots starting sooner than this from now can't be booked — they're hidden from patients too."
            >
              <Input
                name="bookingLeadTimeMinutes"
                type="number"
                min={0}
                max={10080}
                required
                defaultValue={String(settings.bookingLeadTimeMinutes)}
                className="w-full"
              />
            </Field>
            <Field
              label="Cancellation window (hours)"
              hint="How late patients may cancel their own appointment (staff can always cancel)."
            >
              <Input
                name="cancellationWindowHours"
                type="number"
                min={0}
                max={336}
                required
                defaultValue={String(settings.cancellationWindowHours)}
                className="w-full"
              />
            </Field>
            <Field label="Max advance booking (days)" hint="How far ahead patients can book.">
              <Input
                name="maxAdvanceBookingDays"
                type="number"
                min={1}
                max={365}
                required
                defaultValue={String(settings.maxAdvanceBookingDays)}
                className="w-full"
              />
            </Field>
            <Field
              label="Default appointment length (min)"
              hint="Used when a booking has no specific appointment type."
            >
              <Input
                name="defaultAppointmentDurationMin"
                type="number"
                min={5}
                max={240}
                required
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
        {locations.length === 0 ? (
          <Card>
            <EmptyState
              title="No locations yet."
              description="Patients search by city and see your address publicly — at least one branch is required before publishing."
            />
          </Card>
        ) : (
          <div className="grid gap-4 lg:grid-cols-2">
            {locations.map((l) => (
              <Card key={l.id}>
                <form action={updateLocationAction.bind(null, orgId, l.id)} className="flex flex-col gap-3">
                  <CardSubtitle>Branch</CardSubtitle>
                  <Field label="Location name">
                    <Input name="name" defaultValue={l.name} className="w-full" required />
                  </Field>
                  <Field label="Street address">
                    <Input name="addressLine1" defaultValue={l.addressLine1 ?? ""} placeholder="12 Station Road" className="w-full" />
                  </Field>
                  <div className="grid grid-cols-2 gap-3">
                    <Field label="City">
                      <Input name="city" defaultValue={l.city ?? ""} className="w-full" />
                    </Field>
                    <Field label="State">
                      <Input name="state" defaultValue={l.state ?? ""} className="w-full" />
                    </Field>
                    <Field label="Postal code">
                      <Input name="postalCode" defaultValue={l.postalCode ?? ""} className="w-full" />
                    </Field>
                    <Field label="Phone">
                      <Input name="phone" defaultValue={l.phone ?? ""} className="w-full" />
                    </Field>
                  </div>
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <Button variant="ghost">Save location</Button>
                    {/* Deactivate (soft) — schema-supported; keeps history intact.
                        Guarded so a clinic can't strand its only branch. */}
                    {locations.length > 1 ? (
                      <ConfirmSubmit
                        formAction={deactivateLocationAction.bind(null, orgId, l.id)}
                        label="Deactivate"
                        variant="ghost"
                        confirmTitle={`Deactivate ${l.name}?`}
                        confirmMessage="It disappears from public discovery and can't be booked against. Reactivate by editing it later."
                      />
                    ) : null}
                  </div>
                </form>
              </Card>
            ))}
          </div>
        )}
        <Card className="mt-4">
          <CardSubtitle>Add another branch</CardSubtitle>
          <form action={addLocationAction.bind(null, orgId)} className="mt-3 flex max-w-sm flex-col gap-3">
            <Field label="Location name">
              <Input name="name" required placeholder="Main Branch" className="w-full" />
            </Field>
            <Field label="Street address">
              <Input name="addressLine1" placeholder="12 Station Road" className="w-full" />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="City">
                <Input name="city" className="w-full" />
              </Field>
              <Field label="State">
                <Input name="state" className="w-full" />
              </Field>
              <Field label="Postal code">
                <Input name="postalCode" className="w-full" />
              </Field>
              <Field label="Phone">
                <Input name="phone" className="w-full" />
              </Field>
            </div>
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
