import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { db } from "@/lib/db.js";
import { optionalWebUser } from "@/lib/web-context.js";
import { getPublicDoctor } from "@/modules/public/service.js";
import { listMyAccessInOrg } from "@/modules/family/service.js";
import { Badge, Button, Card, CardSubtitle, CardTitle, Field, Input, Select } from "@/components/ui/index.js";
import { PublicHeader } from "../../../public-header";
import { confirmBookingAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function BookAppointmentPage({
  params,
  searchParams,
}: {
  params: Promise<{ doctorId: string }>;
  searchParams: Promise<{ slot?: string; error?: string }>;
}) {
  const { doctorId } = await params;
  const { slot, error } = await searchParams;

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
  const currentPath = `/doctors/${doctorId}/book?slot=${encodeURIComponent(slot)}`;
  const ctx = await optionalWebUser();

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-lg px-5 py-10">
        <h1 className="text-xl font-semibold text-ink">Review your appointment</h1>

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
          {doctor.consultationFeeMinor != null ? (
            <Badge tone="indigo" className="mt-2">
              ₹{(doctor.consultationFeeMinor / 100).toLocaleString()} / visit
            </Badge>
          ) : null}
        </Card>

        {error ? (
          <div className="mt-4 rounded-control border border-down/30 bg-down/5 px-4 py-3 text-sm text-down">
            {error}
          </div>
        ) : null}

        {!ctx ? (
          <Card className="mt-4">
            <p className="text-sm text-ink">Log in or create an account to confirm this appointment.</p>
            <div className="mt-4 flex gap-3">
              <Link
                href={`/login?next=${encodeURIComponent(currentPath)}`}
                className="rounded-full bg-indigo px-5 py-2.5 text-sm font-medium text-white no-underline hover:bg-indigo-dark"
              >
                Log in
              </Link>
              <Link
                href={`/register?next=${encodeURIComponent(currentPath)}`}
                className="rounded-full border border-border bg-card px-5 py-2.5 text-sm font-medium text-ink no-underline hover:bg-surface"
              >
                Sign up
              </Link>
            </div>
          </Card>
        ) : (
          <BookingForm doctorId={doctorId} slot={slot} organizationId={doctor.organization.id} userId={ctx.userId} />
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
}: {
  doctorId: string;
  slot: string;
  organizationId: string;
  userId: string;
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
            <Input name="firstName" required defaultValue={defaultFirst} />
          </Field>
          <Field label="Last name">
            <Input name="lastName" required defaultValue={defaultLast} />
          </Field>
        </div>
        <Field label="Phone" hint="Optional, but helps the clinic reach you.">
          <Input name="phone" defaultValue={user?.phone ?? ""} />
        </Field>
        <Field label="Date of birth" hint="Optional.">
          <Input name="dateOfBirth" type="date" />
        </Field>
        <Field label="Reason for visit" hint="Optional — a short note for the clinic.">
          <Input name="reason" maxLength={200} />
        </Field>
        <div className="mt-1">
          <Button type="submit">Confirm appointment</Button>
        </div>
      </form>
    </Card>
  );
}
