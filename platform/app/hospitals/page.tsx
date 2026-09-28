import type { Metadata } from "next";
import { listPublicOrganizations } from "@/modules/public/service.js";
import { EmptyState, HospitalCard, SearchBar } from "@/components/ui/index.js";
import { PublicHeader } from "../public-header";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Find a hospital or clinic | DoseWise",
  description: "Search hospitals and clinics, view their profiles, and book an appointment with a doctor.",
};

export default async function HospitalsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; city?: string; page?: string }>;
}) {
  const { q, city, page } = await searchParams;
  const pageNum = Number(page ?? "1") || 1;
  const result = await listPublicOrganizations({
    q: q || undefined,
    city: city || undefined,
    page: pageNum,
    pageSize: 20,
  });
  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  // Pagination used to drop the active city filter; keep every filter that is
  // currently applied so page 2 shows the same filtered result set.
  function pageHref(nextPage: number): string {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (city) params.set("city", city);
    params.set("page", String(nextPage));
    return `/hospitals?${params.toString()}`;
  }

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 py-10">
        <h1 className="text-2xl font-semibold text-ink">Find a hospital or clinic</h1>
        <form action="/hospitals" method="get" className="mt-4 max-w-md">
          <SearchBar name="q" defaultValue={q ?? ""} placeholder="Search by name…" />
        </form>

        <p className="mt-4 text-sm text-ink-muted">
          {result.total} {result.total === 1 ? "result" : "results"}
          {city ? <> in {city}</> : null}
        </p>

        {result.data.length === 0 ? (
          <div className="mt-6">
            <EmptyState
              title="No clinics found"
              description={q || city ? "Try a different search or city name, or check back later as more clinics join." : "Check back later as more clinics join DoseWise."}
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
              <a href={pageHref(pageNum - 1)} className="text-indigo no-underline">
                Previous
              </a>
            ) : null}
            <span className="text-ink-muted">
              Page {pageNum} of {totalPages}
            </span>
            {pageNum < totalPages ? (
              <a href={pageHref(pageNum + 1)} className="text-indigo no-underline">
                Next
              </a>
            ) : null}
          </div>
        ) : null}
      </main>
    </div>
  );
}
