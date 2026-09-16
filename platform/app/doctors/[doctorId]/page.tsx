import Link from "next/link";
import { notFound } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { getPublicDoctor } from "@/modules/public/service.js";
import { getPublicDoctorSlots } from "@/modules/patient-booking/service.js";
import { Badge, Card, CardSubtitle, CardTitle } from "@/components/ui/index.js";
import { PublicHeader } from "../../public-header";

export const dynamic = "force-dynamic";

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
  searchParams: Promise<{ date?: string }>;
}) {
  const { doctorId } = await params;
  const { date: dateParam } = await searchParams;

  let doctor: Awaited<ReturnType<typeof getPublicDoctor>>;
  try {
    doctor = await getPublicDoctor(doctorId);
  } catch (err) {
    if (err instanceof AppError && err.code === "NOT_FOUND") notFound();
    throw err;
  }

  const days = nextDays(14);
  const selectedDate = dateParam && /^\d{4}-\d{2}-\d{2}$/.test(dateParam) ? dateParam : isoDate(days[0]!);
  const { slots, timezone } = await getPublicDoctorSlots(doctorId, { date: selectedDate });

  const fee = formatFee(doctor.consultationFeeMinor);

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-5 py-10">
        <div className="flex items-start gap-4">
          <div className="flex-1">
            <h1 className="text-2xl font-semibold text-ink">{doctor.displayName}</h1>
            <p className="mt-1 text-sm text-ink-muted">
              {doctor.specialty ?? "General practice"}
              {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} years experience` : ""}
            </p>
            {doctor.qualifications ? (
              <p className="mt-1 text-sm text-ink-muted">{doctor.qualifications}</p>
            ) : null}
            {doctor.languages.length ? (
              <p className="mt-1 text-sm text-ink-muted">{doctor.languages.join(" · ")}</p>
            ) : null}
          </div>
          {fee ? <Badge tone="indigo">₹{fee} / visit</Badge> : null}
        </div>

        {doctor.bio ? <p className="mt-6 text-sm text-ink">{doctor.bio}</p> : null}

        {doctor.registrationNumber ? (
          <p className="mt-4 text-xs text-ink-muted">Registration: {doctor.registrationNumber}</p>
        ) : null}

        <Card className="mt-8">
          <CardSubtitle>Practices at</CardSubtitle>
          <Link href={`/hospitals/${doctor.organization.slug}`} className="mt-1 block no-underline">
            <CardTitle>{doctor.organization.name}</CardTitle>
          </Link>
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
        <div className="mt-3 flex gap-2 overflow-x-auto pb-2">
          {days.map((d) => {
            const iso = isoDate(d);
            const active = iso === selectedDate;
            return (
              <Link
                key={iso}
                href={`/doctors/${doctorId}?date=${iso}`}
                className={`shrink-0 rounded-full border px-3 py-1.5 text-sm no-underline ${
                  active ? "border-indigo bg-indigo text-white" : "border-border bg-card text-ink hover:border-indigo"
                }`}
              >
                {d.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })}
              </Link>
            );
          })}
        </div>

        {slots.length === 0 ? (
          <p className="mt-6 text-sm text-ink-muted">No open slots on this day — try another date.</p>
        ) : (
          <div className="mt-6 grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-5">
            {slots.map((slot) => (
              <Link
                key={slot.start}
                href={`/doctors/${doctorId}/book?slot=${encodeURIComponent(slot.start)}`}
                className="rounded-control border border-border bg-card px-2 py-2 text-center text-sm text-ink no-underline hover:border-indigo hover:text-indigo"
              >
                {new Date(slot.start).toLocaleTimeString(undefined, {
                  hour: "2-digit",
                  minute: "2-digit",
                  timeZone: timezone,
                })}
              </Link>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
