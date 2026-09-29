import type { Metadata } from "next";
import Link from "next/link";
import { listPublicOrganizations } from "@/modules/public/service.js";
import { EmptyState, HospitalCard, SearchBar } from "@/components/ui/index.js";
import { PublicHeader } from "../public-header";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Find a hospital or clinic | DoseWise",
  description: "Search hospitals and clinics, view their profiles, and book an appointment with a doctor.",
};

const ORG_TYPE_VALUES = ["HOSPITAL", "CLINIC", "POLYCLINIC", "DIAGNOSTIC_CENTER", "OTHER"] as const;
type OrgTypeValue = (typeof ORG_TYPE_VALUES)[number];

const ORG_TYPES: Array<{ value: OrgTypeValue | ""; label: string }> = [
  { value: "", label: "All" },
  { value: "HOSPITAL", label: "Hospitals" },
  { value: "CLINIC", label: "Clinics" },
  { value: "POLYCLINIC", label: "Polyclinics" },
  { value: "DIAGNOSTIC_CENTER", label: "Diagnostic centres" },
];

export default async function HospitalsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; city?: string; type?: string; page?: string }>;
}) {
  const { q, city, type, page } = await searchParams;
  const pageNum = Math.max(1, Number(page ?? "1") || 1);
  const orgType = (ORG_TYPE_VALUES as readonly string[]).includes(type ?? "")
    ? (type as OrgTypeValue)
    : undefined;
  const result = await listPublicOrganizations({
    q: q || undefined,
    city: city || undefined,
    orgType,
    page: pageNum,
    pageSize: 20,
  });
  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  // Filter-preserving links: every chip / page link keeps the query, city and
  // type currently applied so switching one never silently resets the others.
  function href(nextPage: number, nextType: string): string {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (city) params.set("city", city);
    if (nextType) params.set("type", nextType);
    if (nextPage > 1) params.set("page", String(nextPage));
    const qs = params.toString();
    return `/hospitals${qs ? `?${qs}` : ""}`;
  }
  const pageHref = (nextPage: number) => href(nextPage, type ?? "");
  const chipHref = (value: string) => href(1, value);

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 pb-20">
        {/* Hero / search band — the page's own identity, like a real directory
            site, instead of a bare heading above a bare input. */}
        <section className="mt-10 rounded-card bg-linear-to-br from-indigo to-indigo-dark px-6 py-10 text-white sm:px-10 sm:py-12">
          <p className="text-[11px] font-semibold uppercase tracking-wide text-white/75">
            DoseWise directory
          </p>
          <h1 className="mt-2 max-w-xl font-display text-3xl font-bold leading-tight sm:text-4xl">
            Find a hospital or clinic near you
          </h1>
          <p className="mt-3 max-w-lg text-sm text-white/85">
            Browse verified providers, see who&rsquo;s on the panel, and book an appointment online — no
            phone calls needed.
          </p>
          <form action="/hospitals" method="get" className="mt-6 max-w-xl">
            <SearchBar
              name="q"
              defaultValue={q ?? ""}
              placeholder="Search by clinic name…"
              className="border-transparent bg-white shadow-lg"
            />
            {city ? <input type="hidden" name="city" value={city} /> : null}
          </form>
        </section>

        <div className="mt-8 flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-2" aria-label="Filter by provider type">
            {ORG_TYPES.map((t) => {
              const active = (orgType ?? "") === t.value;
              return (
                <Link
                  key={t.value}
                  href={chipHref(t.value)}
                  aria-current={active ? "true" : undefined}
                  className={`rounded-full border px-3.5 py-1.5 text-[12.5px] font-medium no-underline transition-colors ${
                    active
                      ? "border-indigo bg-indigo text-white"
                      : "border-border bg-card text-ink-muted hover:border-indigo/40 hover:text-ink"
                  }`}
                >
                  {t.label}
                </Link>
              );
            })}
          </div>
          {city ? (
            <Link
              href={href(1, type ?? "")}
              className="rounded-full border border-border bg-card px-3 py-1.5 text-[12.5px] text-ink-muted no-underline hover:text-ink"
            >
              City: {city} ✕
            </Link>
          ) : null}
        </div>

        <p className="mt-4 text-sm text-ink-muted" aria-live="polite">
          {result.total} {result.total === 1 ? "provider" : "providers"}
          {city ? <> in {city}</> : null}
          {orgType ? <> · {ORG_TYPES.find((t) => t.value === orgType)?.label.toLowerCase()}</> : null}
        </p>

        {result.data.length === 0 ? (
          <div className="mt-6">
            <EmptyState
              title="No clinics found"
              description={
                q || city || orgType
                  ? "Try a different search, city, or provider type — or check back later as more clinics join."
                  : "Check back later as more clinics join DoseWise."
              }
              action={
                q || city || orgType ? (
                  <Link
                    href="/hospitals"
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
            {result.data.map((org) => (
              <HospitalCard
                key={org.id}
                org={{
                  name: org.name,
                  slug: org.slug,
                  tagline: org.tagline,
                  orgType: org.orgType,
                  verificationStatus: org.verificationStatus,
                  logoUrl: org.logoUrl,
                  city: org.locations[0]?.city ?? null,
                  doctorCount: org._count.doctorProfiles,
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
