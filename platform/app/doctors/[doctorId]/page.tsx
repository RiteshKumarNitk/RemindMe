import { cache } from "react";
import type { Metadata } from "next";
import { AppError } from "@/lib/errors.js";
import { notFound } from "next/navigation";
import { getPublicDoctor } from "@/modules/public/service.js";
import { getPublicDoctorSlots } from "@/modules/patient-booking/service.js";
import { Badge, Card, CardSubtitle, CardTitle, InitialsAvatar } from "@/components/ui/index.js";
import { PublicHeader } from "../../public-header";

export const dynamic = "force-dynamic";

// Shared per-request so generateMetadata and the page don't each hit the DB.
const loadDoctor = cache(async (doctorId: string) => {
  try {
    return await getPublicDoctor(doctorId);
  } catch (err) {
    if (err instanceof AppError && err.code === "NOT_FOUND") return null;
    throw err;
  }
});

export async function generateMetadata({ params }: { params: Promise<{ doctorId: string }> }): Promise<Metadata> {
  const { doctorId } = await params;
  const doctor = await loadDoctor(doctorId);
  if (!doctor) return { title: "Doctor not found | DoseWise" };
  return {
    title: `${doctor.displayName}${doctor.specialty ? ` — ${doctor.specialty}` : ""} | DoseWise`,
    description: `Book an appointment with ${doctor.displayName}${doctor.specialty ? `, ${doctor.specialty}` : ""} at ${doctor.organization.name}.`,
  };
}

function formatFee(minor: number | null): string | null {
  if (minor == null) return null;
  return (minor / 100).toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

function nextDays(n: number): Date[] {
  const out: Date[] = [];
  const now = new Date();
  for (let i = 0; i < n; i++) {
    out.push(new Date(now.getTime() + i * 86_400_000));
  }
  return out;
}

export default async function DoctorDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ doctorId: string }>;
  searchParams: Promise<{ date?: string; type?: string }>;
}) {
  const { doctorId } = await params;
  const { date: dateParam, type: typeParam } = await searchParams;

  const doctor = await loadDoctor(doctorId);
  if (!doctor) notFound();

  // Appointment types are published on the org's public profile; a tampered
  // or stale `type` param simply falls back to the clinic default duration.
  const types = doctor.organization.appointmentTypes ?? [];
  const selectedType = types.find((t) => t.id === typeParam) ?? null;

  const days = nextDays(14);
  const selectedDate = dateParam && /^\d{4}-\d{2}-\d{2}$/.test(dateParam) ? dateParam : isoDate(days[0]!);
  const { slots, timezone, durationMinutes } = await getPublicDoctorSlots(doctorId, {
    date: selectedDate,
    ...(selectedType ? { appointmentTypeId: selectedType.id } : {}),
  });

  const fee = formatFee(doctor.consultationFeeMinor);

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-5 py-10">
        {/* Identity header — avatar block, name, credentials, fee. The
            gradient-initials block stands in until a real photo is uploaded. */}
        <div className="flex items-start gap-4">
          <InitialsAvatar name={doctor.displayName} size="lg" />
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-start justify-between gap-2">
              <h1 className="text-2xl font-semibold text-ink">{doctor.displayName}</h1>
              {fee ? <Badge tone="indigo">₹{fee} / visit</Badge> : null}
            </div>
            <p className="mt-1 text-sm text-ink-muted">
              {doctor.specialty ?? "General practice"}
              {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} years experience` : ""}
            </p>
            {doctor.qualifications ? (
              <p className="mt-1 text-sm text-ink-muted">{doctor.qualifications}</p>
            ) : null}
            {doctor.languages.length ? (
              <p className="mt-1 text-sm text-ink-muted">Speaks: {doctor.languages.join(" · ")}</p>
            ) : null}
          </div>
        </div>

        {doctor.bio ? <p className="mt-6 max-w-2xl text-sm text-ink">{doctor.bio}</p> : null}

        {doctor.registrationNumber ? (
          <p className="mt-4 text-xs text-ink-muted">Registration: {doctor.registrationNumber}</p>
        ) : null}

        <Card className="mt-8">
          <CardSubtitle>Practices at</CardSubtitle>
          <CardTitle as="p" className="mt-1">
            {doctor.organization.name}
          </CardTitle>
          {doctor.organization.locations.length > 0 ? (
            <div className="mt-3 flex flex-col gap-1 text-sm text-ink-muted">
              {doctor.organization.locations.map((loc) => (
                <span key={loc.id}>
                  {loc.name}
                  {loc.city ? ` — ${loc.city}` : ""}
                </span>
              ))}
            </div>
          ) : null}
        </Card>

        <h2 className="mt-10 text-lg font-semibold text-ink">Available appointments</h2>

        {types.length > 0 ? (
          <div className="mt-3 flex flex-wrap gap-2" role="group" aria-label="Appointment type">
            <a
              href={`/doctors/${doctorId}?date=${selectedDate}`}
              aria-current={!selectedType ? "true" : undefined}
              className={`rounded-full border px-3 py-1.5 text-[13px] no-underline ${
                !selectedType
                  ? "border-indigo bg-indigo font-semibold text-white"
                  : "border-border bg-card text-ink hover:border-indigo"
              }`}
            >
              General visit
            </a>
            {types.map((t) => (
              <a
                key={t.id}
                href={`/doctors/${doctorId}?date=${selectedDate}&type=${t.id}`}
                aria-current={selectedType?.id === t.id ? "true" : undefined}
                className={`rounded-full border px-3 py-1.5 text-[13px] no-underline ${
                  selectedType?.id === t.id
                    ? "border-indigo bg-indigo font-semibold text-white"
                    : "border-border bg-card text-ink hover:border-indigo"
                }`}
              >
                {t.name} · {t.durationMinutes} min
              </a>
            ))}
          </div>
        ) : null}
        <p className="mt-2 text-xs text-ink-muted">
          {selectedType
            ? `${selectedType.name} · ${durationMinutes}-minute appointment`
            : `${durationMinutes}-minute appointments (the clinic's default)`}
        </p>

        <div className="mt-3 flex gap-2 overflow-x-auto pb-2" role="group" aria-label="Choose a date">
          {days.map((d) => {
            const iso = isoDate(d);
            const active = iso === selectedDate;
            return (
              <a
                key={iso}
                href={`/doctors/${doctorId}?date=${iso}`}
                aria-current={active ? "date" : undefined}
                className={`shrink-0 rounded-full border px-3 py-1.5 text-sm no-underline ${
                  active
                    ? "border-indigo bg-indigo font-semibold text-white"
                    : "border-border bg-card text-ink hover:border-indigo"
                }`}
              >
                {d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })}
              </a>
            );
          })}
        </div>

        {slots.length === 0 ? (
          <p className="mt-6 text-sm text-ink-muted">No open slots on this day — try another date.</p>
        ) : (
          <div className="mt-6 grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-5">
            {slots.map((slot) => (
              <a
                key={slot.start}
                href={`/doctors/${doctorId}/book?slot=${encodeURIComponent(slot.start)}${selectedType ? `&type=${selectedType.id}` : ""}`}
                className="rounded-control border border-border bg-card px-2 py-2 text-center text-sm font-medium text-ink no-underline hover:border-indigo hover:text-indigo"
              >
                {new Date(slot.start).toLocaleTimeString(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                  timeZone: timezone,
                })}
              </a>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
