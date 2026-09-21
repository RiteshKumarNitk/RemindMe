import type { Metadata } from "next";
import Link from "next/link";
import { listPublicOrganizations } from "@/modules/public/service.js";
import { Badge, Card, CardSubtitle, CardTitle, EmptyState, SearchBar } from "@/components/ui/index.js";
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
        </p>

        {result.data.length === 0 ? (
          <div className="mt-6">
            <EmptyState
              title="No clinics found"
              description="Try a different search, or check back later as more clinics join."
            />
          </div>
        ) : (
          <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
            {result.data.map((org) => (
              <Link key={org.id} href={`/hospitals/${org.slug}`} className="no-underline">
                <Card className="h-full transition-colors hover:border-indigo">
                  <CardTitle>{org.name}</CardTitle>
                  <CardSubtitle className="mt-1">
                    {org.locations[0]?.city ?? org.tagline ?? "Healthcare provider"}
                  </CardSubtitle>
                  <div className="mt-3 flex items-center gap-2">
                    {org.orgType ? <Badge tone="neutral">{org.orgType.replace(/_/g, " ")}</Badge> : null}
                    <Badge tone="indigo">{org._count.doctorProfiles} doctors</Badge>
                  </div>
                </Card>
              </Link>
            ))}
          </div>
        )}

        {totalPages > 1 ? (
          <div className="mt-8 flex items-center justify-center gap-3 text-sm">
            {pageNum > 1 ? (
              <Link href={`/hospitals?${new URLSearchParams({ ...(q ? { q } : {}), page: String(pageNum - 1) })}`} className="text-indigo no-underline">
                Previous
              </Link>
            ) : null}
            <span className="text-ink-muted">
              Page {pageNum} of {totalPages}
            </span>
            {pageNum < totalPages ? (
              <Link href={`/hospitals?${new URLSearchParams({ ...(q ? { q } : {}), page: String(pageNum + 1) })}`} className="text-indigo no-underline">
                Next
              </Link>
            ) : null}
          </div>
        ) : null}
      </main>
    </div>
  );
}
