import { cache } from "react";
import type { Metadata } from "next";
import { AppError } from "@/lib/errors.js";
import { notFound } from "next/navigation";
import { getPublicDoctor } from "@/modules/public/service.js";
import { getPublicDoctorSlots } from "@/modules/patient-booking/service.js";
import { findMyActiveToken, getTokenWindow } from "@/modules/tokens/service.js";
import { optionalWebUser } from "@/lib/web-context.js";
import { Badge, Button, Card, CardSubtitle, CardTitle, DateStrip, InitialsAvatar, LinkButton } from "@/components/ui/index.js";
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

function formatLeadTime(minutes: number): string {
  if (minutes >= 60 && minutes % 60 === 0) {
    const h = minutes / 60;
    return `${h} hour${h === 1 ? "" : "s"}`;
  }
  return `${minutes} minutes`;
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
  searchParams: Promise<{ date?: string; type?: string; location?: string }>;
}) {
  const { doctorId } = await params;
  const { date: dateParam, type: typeParam, location: locationParam } = await searchParams;

  const doctor = await loadDoctor(doctorId);
  if (!doctor) notFound();

  // Appointment types are published on the org's public profile; a tampered
  // or stale `type` param simply falls back to the clinic default duration.
  const types = doctor.organization.appointmentTypes ?? [];
  const selectedType = types.find((t) => t.id === typeParam) ?? null;
  // Branch selection (request §12/§J): explicit, URL-carried, validated
  // against the org's own active locations. Availability is doctor-level, so
  // this choice labels the booking rather than changing the slots.
  const locations = doctor.organization.locations;
  const selectedLocation = locations.find((l) => l.id === locationParam) ?? null;

  const offersTokens = doctor.bookingMode === "SAME_DAY_TOKEN" || doctor.bookingMode === "BOTH";
  const offersSlots = doctor.bookingMode !== "SAME_DAY_TOKEN";
  const viewer = offersTokens ? await optionalWebUser() : null;
  const [tokenWindow, myToken] = offersTokens
    ? await Promise.all([getTokenWindow(doctorId), viewer ? findMyActiveToken(viewer.userId, doctorId) : null])
    : [null, null];

  const days = nextDays(14);
  const selectedDate = dateParam && /^\d{4}-\d{2}-\d{2}$/.test(dateParam) ? dateParam : isoDate(days[0]!);
  // A token-only doctor has no slot grid to show, so don't compute one.
  const { slots, timezone, durationMinutes, slotsHiddenByLeadTime, bookingLeadTimeMinutes } = offersSlots
    ? await getPublicDoctorSlots(doctorId, {
        date: selectedDate,
        ...(selectedType ? { appointmentTypeId: selectedType.id } : {}),
      })
    : { slots: [], timezone: "UTC", durationMinutes: 0, slotsHiddenByLeadTime: 0, bookingLeadTimeMinutes: 0 };

  // Every filter chip preserves the other selections — a date chip that
  // dropped `type`/`location` would silently reset the patient's choices
  // (and the slot math) when they pick a different day.
  const chipHref = (date: string, typeId?: string, locationId?: string) => {
    const params = new URLSearchParams({ date });
    if (typeId) params.set("type", typeId);
    if (locationId) params.set("location", locationId);
    return `/doctors/${doctorId}?${params.toString()}`;
  };
  const selectedTypeId = selectedType?.id;
  const selectedLocationId = selectedLocation?.id;

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

        {tokenWindow ? (
          <>
            <h2 className="mt-10 text-lg font-semibold text-ink">
              {offersSlots ? "Book with this doctor" : "Today’s token booking"}
            </h2>
            <Card className="mt-3">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <CardTitle as="p">Today&rsquo;s token</CardTitle>
                  <p className="mt-1 text-sm text-ink-muted">
                    Get a queue number for today&rsquo;s clinic. Booking {tokenWindow.opensAt}–{tokenWindow.closesAt},
                    queue starts {tokenWindow.queueStartAt} (clinic time).
                  </p>
                  <p className="mt-2 text-sm text-ink">
                    {myToken?.queueEntry
                      ? `You have token #${myToken.queueEntry.tokenNumber} for today.`
                      : tokenWindow.status === "OPEN"
                        ? "Today’s token booking is open."
                        : tokenWindow.status === "NOT_YET_OPEN"
                          ? `Today’s token booking opens at ${tokenWindow.opensAt}.`
                          : tokenWindow.errorCode === "TOKEN_LIMIT_REACHED"
                            ? "Today’s token limit has been reached."
                            : "Today’s token booking is closed."}
                  </p>
                </div>
                {myToken?.queueEntry ? (
                  <LinkButton href={`/dashboard/${myToken.organizationId}/appointments/${myToken.id}`}>View token</LinkButton>
                ) : tokenWindow.bookable ? (
                  <LinkButton href={`/doctors/${doctorId}/token`}>Book today&rsquo;s token</LinkButton>
                ) : (
                  <Button disabled>
                    {tokenWindow.status === "NOT_YET_OPEN" ? `Booking opens at ${tokenWindow.opensAt}` : "Closed for today"}
                  </Button>
                )}
              </div>
            </Card>
          </>
        ) : null}

        {offersSlots ? (
        <>
        <h2 className="mt-10 text-lg font-semibold text-ink">
          {tokenWindow ? "Or choose a scheduled appointment" : "Available appointments"}
        </h2>

        {types.length > 0 ? (
          <div className="mt-3 flex flex-wrap gap-2" role="group" aria-label="Appointment type">
            <a
              href={chipHref(selectedDate)}
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
                href={chipHref(selectedDate, t.id, selectedLocationId)}
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
        {locations.length > 1 ? (
          <div className="mt-3 flex flex-wrap gap-2" role="group" aria-label="Branch">
            <a
              href={chipHref(selectedDate, selectedTypeId)}
              aria-current={!selectedLocation ? "true" : undefined}
              className={`rounded-full border px-3 py-1.5 text-[13px] no-underline ${
                !selectedLocation
                  ? "border-indigo bg-indigo font-semibold text-white"
                  : "border-border bg-card text-ink hover:border-indigo"
              }`}
            >
              No branch preference
            </a>
            {locations.map((l) => (
              <a
                key={l.id}
                href={chipHref(selectedDate, selectedTypeId, l.id)}
                aria-current={selectedLocation?.id === l.id ? "true" : undefined}
                className={`rounded-full border px-3 py-1.5 text-[13px] no-underline ${
                  selectedLocation?.id === l.id
                    ? "border-indigo bg-indigo font-semibold text-white"
                    : "border-border bg-card text-ink hover:border-indigo"
                }`}
              >
                {l.name}
                {l.city ? ` — ${l.city}` : ""}
              </a>
            ))}
          </div>
        ) : null}

        <p className="mt-2 text-xs text-ink-muted">
          {selectedType
            ? `${selectedType.name} · ${durationMinutes}-minute appointment`
            : `${durationMinutes}-minute appointments (the clinic's default)`}
        </p>

        <DateStrip role="group" ariaLabel="Choose a date" className="mt-3">
          {days.map((d) => {
            const iso = isoDate(d);
            const active = iso === selectedDate;
            return (
              <a
                key={iso}
                href={chipHref(iso, selectedTypeId, selectedLocationId)}
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
        </DateStrip>

        {slots.length === 0 ? (
          // Explain lead time only when it's actually why the day is empty —
          // "no availability today" and "this clinic books ≥2h ahead" look
          // identical to a patient otherwise.
          <p className="mt-6 text-sm text-ink-muted">
            {slotsHiddenByLeadTime > 0
              ? `No open slots this day — this clinic takes bookings at least ${formatLeadTime(bookingLeadTimeMinutes)} ahead. Try a later date.`
              : "No open slots on this day — try another date."}
          </p>
        ) : (
          <div className="mt-6 grid grid-cols-3 gap-2 sm:grid-cols-4 md:grid-cols-5">
            {slots.map((slot) => (
              <a
                key={slot.start}
                href={`/doctors/${doctorId}/book?slot=${encodeURIComponent(slot.start)}${selectedType ? `&type=${selectedType.id}` : ""}${selectedLocation ? `&location=${selectedLocation.id}` : ""}`}
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
        </>
        ) : null}
      </main>
    </div>
  );
}
