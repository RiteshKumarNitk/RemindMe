import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { db } from "@/lib/db.js";
import { optionalWebUser } from "@/lib/web-context.js";
import { getPublicDoctor } from "@/modules/public/service.js";
import { listMyAccessInOrg } from "@/modules/family/service.js";
import { Badge, Button, Card, CardSubtitle, CardTitle, Field, Input, Notice, Select } from "@/components/ui/index.js";
import { PublicHeader } from "../../../public-header";
import { confirmBookingAction } from "./actions.js";

export const dynamic = "force-dynamic";

/**
 * Three-step booking flow across two screens: step 1 (doctor, date, time)
 * happens on the doctor profile; this page is step 2 (details + review);
 * confirmation after submit is step 3. The indicator is presentational —
 * the actual booking mechanics (server action + hidden inputs) are unchanged.
 */
function BookingSteps({ current }: { current: 2 | 3 }) {
  const steps = ["Doctor & time", "Your details", "Confirmation"];
  return (
    <ol className="flex flex-wrap items-center gap-2 text-sm" aria-label="Booking progress">
      {steps.map((label, i) => {
        const step = i + 1;
        const state = step < current ? "done" : step === current ? "current" : "todo";
        return (
          <li key={label} className="flex items-center gap-2">
            <span
              aria-current={state === "current" ? "step" : undefined}
              className={`flex items-center gap-1.5 rounded-full border px-3 py-1 ${
                state === "current"
                  ? "border-indigo bg-indigo font-semibold text-white"
                  : state === "done"
                    ? "border-ok/30 bg-ok/10 text-ok"
                    : "border-border bg-card text-ink-muted"
              }`}
            >
              {state === "done" ? (
                <svg aria-hidden viewBox="0 0 16 16" className="h-3.5 w-3.5" fill="currentColor">
                  <path fillRule="evenodd" d="M13.7 4.3a1 1 0 0 1 0 1.4l-6.5 6.5a1 1 0 0 1-1.4 0l-3-3a1 1 0 1 1 1.4-1.4L6.5 10l5.8-5.7a1 1 0 0 1 1.4 0Z" clipRule="evenodd" />
                </svg>
              ) : (
                <span className="tabular-nums">{step}</span>
              )}
              {label}
            </span>
            {step < steps.length ? <span aria-hidden className="text-ink-faint">→</span> : null}
          </li>
        );
      })}
    </ol>
  );
}

export default async function BookAppointmentPage({
  params,
  searchParams,
}: {
  params: Promise<{ doctorId: string }>;
  searchParams: Promise<{ slot?: string; type?: string; error?: string }>;
}) {
  const { doctorId } = await params;
  const { slot, type: typeParam, error } = await searchParams;

  if (!slot || Number.isNaN(new Date(slot).getTime())) {
    redirect(`/doctors/${doctorId}`);
  }

  let doctor: Awaited<ReturnType<typeof getPublicDoctor>>;
  try {
    doctor = await getPublicDoctor(doctorId);
  } catch (err) {
    if (err instanceof AppError && err.code === "NOT_FOUND") notFound();
    throw err;
  }

  const slotDate = new Date(slot);
  // The chosen appointment type rides along from the doctor page; validated
  // against the org's published types (a tampered id falls back to default).
  const types = doctor.organization.appointmentTypes ?? [];
  const selectedType = types.find((t) => t.id === typeParam) ?? null;
  const branch =
    doctor.organization.locations.find((l) => l.id && selectedType) ?? doctor.organization.locations[0] ?? null;
  const currentPath = `/doctors/${doctorId}/book?slot=${encodeURIComponent(slot)}${selectedType ? `&type=${selectedType.id}` : ""}`;
  const ctx = await optionalWebUser();

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-lg px-5 py-10">
        <BookingSteps current={2} />
        <h1 className="mt-5 text-xl font-semibold text-ink">Review your appointment</h1>

        <Card className="mt-4">
          <CardSubtitle>Appointment with</CardSubtitle>
          <CardTitle as="p" className="mt-1">{doctor.displayName}</CardTitle>
          <p className="text-sm text-ink-muted">{doctor.specialty ?? "General practice"}</p>
          <p className="mt-3 text-sm text-ink">{doctor.organization.name}</p>
          <p className="mt-3 text-sm font-medium text-ink">
            {slotDate.toLocaleString(undefined, {
              weekday: "long",
              month: "long",
              day: "numeric",
              hour: "2-digit",
              minute: "2-digit",
            })}
          </p>
          {selectedType ? (
            <p className="mt-1 text-sm text-ink-muted">
              {selectedType.name} · {selectedType.durationMinutes} min
            </p>
          ) : null}
          {branch ? (
            <p className="mt-2 text-sm text-ink-muted">
              {branch.name}
              {branch.city ? ` — ${branch.city}` : ""}
            </p>
          ) : null}
          {doctor.consultationFeeMinor != null ? (
            <Badge tone="indigo" className="mt-2">
              ₹{(doctor.consultationFeeMinor / 100).toLocaleString()} / visit
            </Badge>
          ) : null}
        </Card>

        {error ? (
          <div className="mt-4">
            <Notice tone="down">{error}</Notice>
          </div>
        ) : null}

        {!ctx ? (
          <Card className="mt-4">
            <p className="text-sm text-ink">Log in or create an account to confirm this appointment.</p>
            <div className="mt-4 flex gap-3">
              <Link
                href={`/login?next=${encodeURIComponent(currentPath)}`}
                className="rounded-control bg-indigo px-5 py-2.5 text-sm font-medium text-white no-underline hover:bg-indigo-dark"
              >
                Log in
              </Link>
              <Link
                href={`/register?next=${encodeURIComponent(currentPath)}`}
                className="rounded-control border border-border bg-card px-5 py-2.5 text-sm font-medium text-ink no-underline hover:bg-surface"
              >
                Sign up
              </Link>
            </div>
            <p className="mt-3 text-xs text-ink-muted">
              Changed your mind about the time?{" "}
              <Link href={`/doctors/${doctorId}`} className="text-indigo">
                Pick a different slot
              </Link>
              .
            </p>
          </Card>
        ) : (
          <BookingForm
            doctorId={doctorId}
            slot={slot}
            organizationId={doctor.organization.id}
            userId={ctx.userId}
            appointmentTypeId={selectedType?.id}
          />
        )}
      </main>
    </div>
  );
}

async function BookingForm({
  doctorId,
  slot,
  organizationId,
  userId,
  appointmentTypeId,
}: {
  doctorId: string;
  slot: string;
  organizationId: string;
  userId: string;
  appointmentTypeId?: string;
}) {
  const [user, dependents] = await Promise.all([
    db.user.findUnique({ where: { id: userId }, select: { fullName: true, phone: true } }),
    listMyAccessInOrg(userId, organizationId),
  ]);
  const [defaultFirst = "", ...restName] = (user?.fullName ?? "").trim().split(/\s+/);
  const defaultLast = restName.join(" ");

  return (
    <Card className="mt-4">
      <CardSubtitle>Your details</CardSubtitle>
      <form action={confirmBookingAction.bind(null, doctorId, slot)} className="mt-3 flex flex-col gap-4">
        <input type="hidden" name="organizationId" value={organizationId} />
        {appointmentTypeId ? <input type="hidden" name="appointmentTypeId" value={appointmentTypeId} /> : null}
        {dependents.length > 0 ? (
          <Field label="Who is this appointment for?">
            <Select name="patientId" className="w-full" defaultValue="">
              <option value="">Myself</option>
              {dependents.map((d) => (
                <option key={d.patient.id} value={d.patient.id}>
                  {d.patient.firstName} {d.patient.lastName}
                </option>
              ))}
            </Select>
          </Field>
        ) : null}
        <div className="grid grid-cols-2 gap-3">
          <Field label="First name" hint="Your own details — used even when booking for a dependent above.">
            <Input name="firstName" required defaultValue={defaultFirst} className="w-full" />
          </Field>
          <Field label="Last name">
            <Input name="lastName" required defaultValue={defaultLast} className="w-full" />
          </Field>
        </div>
        <Field label="Phone" hint="Optional, but helps the clinic reach you.">
          <Input name="phone" type="tel" autoComplete="tel" defaultValue={user?.phone ?? ""} className="w-full" />
        </Field>
        <Field label="Date of birth" hint="Optional.">
          <Input name="dateOfBirth" type="date" className="w-full" />
        </Field>
        <Field label="Reason for visit" hint="Optional — a short note for the clinic.">
          <Input name="reason" maxLength={200} className="w-full" />
        </Field>
        <div className="mt-1">
          <Button type="submit" size="lg" className="w-full">Confirm appointment</Button>
        </div>
      </form>
    </Card>
  );
}
