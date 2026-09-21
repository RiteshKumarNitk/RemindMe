import type { Metadata } from "next";
import Link from "next/link";
import { listPublicDoctors } from "@/modules/public/service.js";
import { Card, CardSubtitle, CardTitle, EmptyState, SearchBar } from "@/components/ui/index.js";
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
        </p>

        {result.data.length === 0 ? (
          <div className="mt-6">
            <EmptyState
              title="No doctors found"
              description="Try a different search, or check back later as more doctors join."
            />
          </div>
        ) : (
          <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
            {result.data.map((doctor) => (
              <Link key={doctor.id} href={`/doctors/${doctor.id}`} className="no-underline">
                <Card className="h-full transition-colors hover:border-indigo">
                  <CardTitle>{doctor.displayName}</CardTitle>
                  <CardSubtitle className="mt-1">
                    {doctor.specialty ?? "General practice"}
                    {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} yrs` : ""}
                  </CardSubtitle>
                  <p className="mt-2 text-sm text-ink-muted">{doctor.organization.name}</p>
                </Card>
              </Link>
            ))}
          </div>
        )}

        {totalPages > 1 ? (
          <div className="mt-8 flex items-center justify-center gap-3 text-sm">
            {pageNum > 1 ? (
              <Link href={`/doctors?${new URLSearchParams({ ...(q ? { q } : {}), page: String(pageNum - 1) })}`} className="text-indigo no-underline">
                Previous
              </Link>
            ) : null}
            <span className="text-ink-muted">
              Page {pageNum} of {totalPages}
            </span>
            {pageNum < totalPages ? (
              <Link href={`/doctors?${new URLSearchParams({ ...(q ? { q } : {}), page: String(pageNum + 1) })}`} className="text-indigo no-underline">
                Next
              </Link>
            ) : null}
          </div>
        ) : null}
      </main>
    </div>
  );
}
