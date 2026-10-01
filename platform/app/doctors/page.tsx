import type { Metadata } from "next";
import Link from "next/link";
import { listPublicDoctors } from "@/modules/public/service.js";
import { DoctorCard, EmptyState, SearchBar } from "@/components/ui/index.js";
import { PublicHeader } from "../public-header";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Find a doctor | DoseWise",
  description: "Search doctors by name or specialty, see real availability, and book an appointment.",
};

const SPECIALTIES = [
  "General Physician",
  "Pediatrics",
  "Cardiology",
  "Dermatology",
  "Orthopedics",
  "Gynecology",
  "ENT",
  "Neurology",
];

export default async function DoctorsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; specialty?: string; page?: string }>;
}) {
  const { q, specialty, page } = await searchParams;
  const pageNum = Math.max(1, Number(page ?? "1") || 1);
  const result = await listPublicDoctors({
    q: q || undefined,
    specialty: specialty || undefined,
    page: pageNum,
    pageSize: 20,
  });
  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  // Filter-preserving links: specialty chips and pagination keep the query and
  // specialty currently applied so switching one never resets the other.
  function href(nextPage: number, nextSpecialty: string): string {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (nextSpecialty) params.set("specialty", nextSpecialty);
    if (nextPage > 1) params.set("page", String(nextPage));
    const qs = params.toString();
    return `/doctors${qs ? `?${qs}` : ""}`;
  }
  const pageHref = (nextPage: number) => href(nextPage, specialty ?? "");
  const chipHref = (value: string) => href(1, value);

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 pb-20">
        {/* Hero / search band — mirrors /hospitals so both directories feel
            like one product instead of two half-related pages. */}
        <section className="mt-10 rounded-card bg-linear-to-br from-indigo to-indigo-dark px-6 py-10 text-white sm:px-10 sm:py-12">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-white/75">
            DoseWise directory
          </p>
          <h1 className="mt-2 max-w-xl font-display text-3xl font-bold leading-tight sm:text-4xl">
            Book the right doctor, in minutes
          </h1>
          <p className="mt-3 max-w-lg text-sm text-white/85">
            Real availability, instant confirmation, and your visit history kept in one place.
          </p>
          <form action="/doctors" method="get" className="mt-6 max-w-xl">
            <SearchBar
              name="q"
              defaultValue={q ?? ""}
              placeholder="Search by doctor name or specialty…"
              className="border-transparent bg-white shadow-lg"
            />
            {specialty ? <input type="hidden" name="specialty" value={specialty} /> : null}
          </form>
        </section>

        <div className="mt-8 flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-2" aria-label="Filter by specialty">
            <Link
              href={chipHref("")}
              aria-current={!specialty ? "true" : undefined}
              className={`rounded-full border px-3.5 py-1.5 text-[12.5px] font-medium no-underline transition-colors ${
                !specialty
                  ? "border-indigo bg-indigo text-white"
                  : "border-border bg-card text-ink-muted hover:border-indigo/40 hover:text-ink"
              }`}
            >
              All specialties
            </Link>
            {SPECIALTIES.map((s) => {
              const active = specialty === s;
              return (
                <Link
                  key={s}
                  href={chipHref(s)}
                  aria-current={active ? "true" : undefined}
                  className={`rounded-full border px-3.5 py-1.5 text-[12.5px] font-medium no-underline transition-colors ${
                    active
                      ? "border-indigo bg-indigo text-white"
                      : "border-border bg-card text-ink-muted hover:border-indigo/40 hover:text-ink"
                  }`}
                >
                  {s}
                </Link>
              );
            })}
          </div>
        </div>

        <p className="mt-4 text-sm text-ink-muted" aria-live="polite">
          {result.total} {result.total === 1 ? "doctor" : "doctors"}
          {specialty ? <> · {specialty}</> : null}
        </p>

        {result.data.length === 0 ? (
          <div className="mt-6">
            <EmptyState
              title="No doctors found"
              description={
                q || specialty
                  ? "Try a different name or specialty, or check back later as more doctors join."
                  : "Check back later as more doctors join DoseWise."
              }
              action={
                q || specialty ? (
                  <Link
                    href="/doctors"
                    className="rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold text-ink no-underline"
                  >
                    Clear all filters
                  </Link>
                ) : undefined
              }
            />
          </div>
        ) : (
          <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
            {result.data.map((doctor) => (
              <DoctorCard
                key={doctor.id}
                doctor={{
                  id: doctor.id,
                  displayName: doctor.displayName,
                  specialty: doctor.specialty,
                  photoUrl: doctor.photoUrl,
                  yearsOfExperience: doctor.yearsOfExperience,
                  languages: doctor.languages,
                  consultationFeeMinor: doctor.consultationFeeMinor,
                  bookingMode: doctor.bookingMode,
                  organization: { name: doctor.organization.name, slug: doctor.organization.slug },
                }}
              />
            ))}
          </div>
        )}

        {totalPages > 1 ? (
          <div className="mt-8 flex items-center justify-center gap-3 text-sm">
            {pageNum > 1 ? (
              <Link
                href={pageHref(pageNum - 1)}
                className="rounded-control border border-border bg-card px-3.5 py-2 text-ink no-underline hover:bg-surface"
              >
                ← Previous
              </Link>
            ) : null}
            <span className="text-ink-muted">
              Page {pageNum} of {totalPages}
            </span>
            {pageNum < totalPages ? (
              <Link
                href={pageHref(pageNum + 1)}
                className="rounded-control border border-border bg-card px-3.5 py-2 text-ink no-underline hover:bg-surface"
              >
                Next →
              </Link>
            ) : null}
          </div>
        ) : null}
      </main>
    </div>
  );
}
