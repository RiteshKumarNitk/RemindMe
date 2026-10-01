import type { Metadata } from "next";
import Link from "next/link";
import {
  listPublicDoctors,
  listPublicOrganizations,
} from "@/modules/public/service.js";
import {
  DoctorCard,
  EmptyState,
  HospitalCard,
  SearchBar,
  SectionHeading,
} from "@/components/ui/index.js";
import { PublicHeader } from "../public-header";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Search healthcare providers | DoseWise",
  description: "Search doctors, clinics, hospitals and diagnostic centres on DoseWise.",
};

const ORG_TYPE_VALUES = ["HOSPITAL", "CLINIC", "POLYCLINIC", "DIAGNOSTIC_CENTER", "OTHER"] as const;
type OrgTypeValue = (typeof ORG_TYPE_VALUES)[number];

const ORG_TYPES: Array<{ value: OrgTypeValue | ""; label: string }> = [
  { value: "", label: "All types" },
  { value: "HOSPITAL", label: "Hospitals" },
  { value: "CLINIC", label: "Clinics" },
  { value: "POLYCLINIC", label: "Polyclinics" },
  { value: "DIAGNOSTIC_CENTER", label: "Diagnostic centres" },
];

/**
 * Unified search (request §18): one query across doctors AND organizations,
 * with clearly separated result groups. Composes the exact same services the
 * /hospitals and /doctors pages use — no new queries, no client-side
 * filtering of a full table.
 */
export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; type?: string; city?: string }>;
}) {
  const { q, type, city } = await searchParams;
  const term = q?.trim() ?? "";
  const orgType = (ORG_TYPE_VALUES as readonly string[]).includes(type ?? "")
    ? (type as OrgTypeValue)
    : undefined;
  const cityFilter = city?.trim() || undefined;

  const [orgs, doctors] = await Promise.all([
    listPublicOrganizations({ q: term || undefined, orgType, city: cityFilter, page: 1, pageSize: 12 }),
    listPublicDoctors({ q: term || undefined, page: 1, pageSize: 12 }),
  ]);

  const hasFilters = Boolean(term || orgType || cityFilter);
  const chipHref = (value: string) => {
    const params = new URLSearchParams();
    if (term) params.set("q", term);
    if (cityFilter) params.set("city", cityFilter);
    if (value) params.set("type", value);
    const qs = params.toString();
    return `/search${qs ? `?${qs}` : ""}`;
  };

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 py-10">
        <h1 className="font-display text-2xl font-bold text-ink">Search healthcare providers</h1>
        <p className="mt-1 text-sm text-ink-muted">
          Doctors, clinics, hospitals and diagnostic centres — one search.
        </p>

        <form action="/search" method="get" className="mt-5 max-w-2xl">
          <SearchBar name="q" defaultValue={term} placeholder="Search doctors, clinics, hospitals…" />
          {orgType ? <input type="hidden" name="type" value={orgType} /> : null}
          {cityFilter ? <input type="hidden" name="city" value={cityFilter} /> : null}
        </form>

        <div className="mt-4 flex flex-wrap gap-2">
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

        {!hasFilters && orgs.total === 0 && doctors.total === 0 ? (
          <div className="mt-10">
            <EmptyState
              title="Nothing to search yet"
              description="Type a doctor's name, a specialty, or a clinic to begin — or browse the directories below."
              action={
                <div className="flex flex-wrap justify-center gap-2">
                  <Link href="/hospitals" className="rounded-xl bg-indigo px-4 py-2.5 text-sm font-semibold text-white no-underline">
                    Browse clinics
                  </Link>
                  <Link href="/doctors" className="rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold text-ink no-underline">
                    Browse doctors
                  </Link>
                </div>
              }
            />
          </div>
        ) : null}

        {doctors.data.length > 0 ? (
          <section className="mt-10" aria-label="Doctor results">
            <SectionHeading
              title={term ? `Doctors matching “${term}”` : "Doctors"}
              action={<Link href="/doctors" className="text-sm text-indigo no-underline">All doctors →</Link>}
            />
            <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {doctors.data.slice(0, 6).map((d) => (
                <DoctorCard
                  key={d.id}
                  doctor={{
                    id: d.id,
                    displayName: d.displayName,
                    specialty: d.specialty,
                    photoUrl: d.photoUrl,
                    yearsOfExperience: d.yearsOfExperience,
                    languages: d.languages,
                    consultationFeeMinor: d.consultationFeeMinor,
                    bookingMode: d.bookingMode,
                    organization: { name: d.organization.name, slug: d.organization.slug },
                  }}
                />
              ))}
            </div>
          </section>
        ) : null}

        {orgs.data.length > 0 ? (
          <section className="mt-10" aria-label="Clinic results">
            <SectionHeading
              title={
                cityFilter
                  ? `Clinics & hospitals in ${cityFilter}`
                  : term
                    ? `Clinics & hospitals matching “${term}”`
                    : "Clinics & hospitals"
              }
              action={<Link href="/hospitals" className="text-sm text-indigo no-underline">All clinics →</Link>}
            />
            <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              {orgs.data.slice(0, 6).map((o) => (
                <HospitalCard
                  key={o.id}
                  org={{
                    name: o.name,
                    slug: o.slug,
                    tagline: o.tagline,
                    orgType: o.orgType,
                    verificationStatus: o.verificationStatus,
                    logoUrl: o.logoUrl,
                    city: o.locations[0]?.city ?? null,
                    doctorCount: o._count.doctorProfiles,
                  }}
                />
              ))}
            </div>
          </section>
        ) : null}

        {hasFilters && orgs.data.length === 0 && doctors.data.length === 0 ? (
          <div className="mt-10">
            <EmptyState
              title="No matches"
              description={`Nothing found for ${term ? `“${term}”` : "those filters"}. Try a different spelling or clear the filters.`}
              action={
                <Link href="/search" className="rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold text-ink no-underline">
                  Clear search
                </Link>
              }
            />
          </div>
        ) : null}
      </main>
    </div>
  );
}
