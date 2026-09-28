import type { Metadata } from "next";
import { listPublicDoctors } from "@/modules/public/service.js";
import { DoctorCard, EmptyState, SearchBar } from "@/components/ui/index.js";
import { PublicHeader } from "../public-header";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Find a doctor | DoseWise",
  description: "Search doctors by name or specialty, see real availability, and book an appointment.",
};

export default async function DoctorsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; specialty?: string; page?: string }>;
}) {
  const { q, specialty, page } = await searchParams;
  const pageNum = Number(page ?? "1") || 1;
  const result = await listPublicDoctors({
    q: q || undefined,
    specialty: specialty || undefined,
    page: pageNum,
    pageSize: 20,
  });
  const totalPages = Math.max(1, Math.ceil(result.total / result.pageSize));

  // Pagination used to drop the specialty filter; keep it alongside the query.
  function pageHref(nextPage: number): string {
    const params = new URLSearchParams();
    if (q) params.set("q", q);
    if (specialty) params.set("specialty", specialty);
    params.set("page", String(nextPage));
    return `/doctors?${params.toString()}`;
  }

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 py-10">
        <h1 className="text-2xl font-semibold text-ink">Find a doctor</h1>
        <form action="/doctors" method="get" className="mt-4 max-w-md">
          <SearchBar name="q" defaultValue={q ?? ""} placeholder="Search by name or specialty…" />
        </form>

        <p className="mt-4 text-sm text-ink-muted">
          {result.total} {result.total === 1 ? "result" : "results"}
          {specialty ? <> in {specialty}</> : null}
        </p>

        {result.data.length === 0 ? (
          <div className="mt-6">
            <EmptyState
              title="No doctors found"
              description={q || specialty ? "Try a different name or specialty, or check back later as more doctors join." : "Check back later as more doctors join DoseWise."}
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
                  organization: { name: doctor.organization.name, slug: doctor.organization.slug },
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
