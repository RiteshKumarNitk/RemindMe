import type { Metadata } from "next";
import Link from "next/link";
import { listPublicDoctors, listPublicOrganizations } from "@/modules/public/service.js";
import { Badge, Card, CardSubtitle, CardTitle, SearchBar } from "@/components/ui/index.js";
import { PublicHeader } from "./public-header";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "DoseWise — Find a doctor and book an appointment",
  description: "Search doctors and clinics, see real availability, and book an appointment online.",
};

export default async function HomePage() {
  const [hospitals, doctors] = await Promise.all([
    listPublicOrganizations({ page: 1, pageSize: 6 }),
    listPublicDoctors({ page: 1, pageSize: 6 }),
  ]);

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 pb-20">
        <section className="flex flex-col items-center gap-5 py-16 text-center">
          <h1 className="max-w-xl text-3xl font-semibold text-ink sm:text-4xl">
            Find the right healthcare for you
          </h1>
          <p className="max-w-md text-sm text-ink-muted">
            Search doctors and clinics, see real availability, and book an appointment.
          </p>
          <form action="/doctors" method="get" className="w-full max-w-md">
            <SearchBar name="q" placeholder="Search doctors, hospitals, specialties…" />
          </form>
          <div className="flex gap-3">
            <Link
              href="/doctors"
              className="rounded-full bg-indigo px-5 py-2.5 text-sm font-medium text-white no-underline hover:bg-indigo-dark"
            >
              Find a doctor
            </Link>
            <Link
              href="/hospitals"
              className="rounded-full border border-border bg-card px-5 py-2.5 text-sm font-medium text-ink no-underline hover:bg-surface"
            >
              Find a hospital
            </Link>
          </div>
        </section>

        {hospitals.data.length > 0 ? (
          <section className="py-8">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-ink">Hospitals &amp; clinics</h2>
              <Link href="/hospitals" className="text-sm text-indigo no-underline">
                See all
              </Link>
            </div>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              {hospitals.data.map((org) => (
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
          </section>
        ) : null}

        {doctors.data.length > 0 ? (
          <section className="py-8">
            <div className="mb-4 flex items-center justify-between">
              <h2 className="text-lg font-semibold text-ink">Doctors</h2>
              <Link href="/doctors" className="text-sm text-indigo no-underline">
                See all
              </Link>
            </div>
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              {doctors.data.map((doctor) => (
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
          </section>
        ) : null}

        {hospitals.data.length === 0 && doctors.data.length === 0 ? (
          <p className="py-12 text-center text-sm text-ink-muted">
            No clinics have published their public profile yet — check back soon.
          </p>
        ) : null}
      </main>
    </div>
  );
}
