import type { Metadata } from "next";
import Link from "next/link";
import { listPublicDoctors, listPublicOrganizations } from "@/modules/public/service.js";
import {
  Card,
  CardSubtitle,
  CardTitle,
  DoctorCard,
  HospitalCard,
  LinkButton,
  SearchBar,
  SectionHeading,
} from "@/components/ui/index.js";
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
          <div className="flex flex-wrap justify-center gap-3">
            <LinkButton href="/doctors">Find a doctor</LinkButton>
            <LinkButton href="/hospitals" variant="secondary">
              Find a hospital
            </LinkButton>
          </div>
        </section>

        {/* Single-page explainer: what DoseWise is and how it works, so a first
            visit explains the product even before scrolling to the live directory. */}
        <section className="py-10" aria-label="What is DoseWise">
          <SectionHeading title="What is DoseWise?" />
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            {[
              {
                title: "Real-time availability",
                text: "Clinics publish their consultation types and open slots — what you see is what's actually free right now.",
              },
              {
                title: "Book in under a minute",
                text: "Pick a doctor, a slot, and confirm. No account walls, no callbacks, no waiting on hold.",
              },
              {
                title: "Your records, always with you",
                text: "Prescriptions and visit history live in your DoseWise app, linked to each appointment.",
              },
            ].map((f) => (
              <Card key={f.title} className="gap-2 p-5">
                <CardTitle className="text-base">{f.title}</CardTitle>
                <CardSubtitle className="leading-relaxed">{f.text}</CardSubtitle>
              </Card>
            ))}

          </div>
        </section>

        <section className="py-10" aria-label="How it works">
          <SectionHeading title="How it works" />
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-4">
            {[
              { step: "1", title: "Search", text: "Find a verified doctor, clinic or diagnostic centre by name, specialty or city." },
              { step: "2", title: "Book", text: "Choose a real open slot and confirm — instantly, without phone calls." },
              { step: "3", title: "Visit", text: "Get local queue tokens so you walk in when it's actually your turn." },
              { step: "4", title: "Records", text: "Prescriptions and visit history are saved to your account automatically." },
            ].map((s) => (
              <div key={s.step} className="rounded-card border border-border bg-card p-5">
                <div className="flex h-8 w-8 items-center justify-center rounded-full bg-indigo font-display text-sm font-bold text-white">{s.step}</div>
                <p className="mt-3 font-medium text-ink">{s.title}</p>
                <p className="mt-1 text-[12.5px] leading-relaxed text-ink-muted">{s.text}</p>
              </div>
            ))}
          </div>
        </section>

        {/* For clinics: the platform pitch with a direct path into onboarding. */}
        <section className="py-10">
          <div className="flex flex-col items-start justify-between gap-6 rounded-card bg-linear-to-br from-indigo to-indigo-dark p-8 text-white sm:flex-row sm:items-center sm:p-10">
            <div className="max-w-xl">
              <p className="text-[11px] font-semibold uppercase tracking-wide text-white/75">For clinics</p>
              <h2 className="mt-2 font-display text-2xl font-bold leading-snug">Run your clinic on DoseWise</h2>
              <p className="mt-2 text-sm leading-relaxed text-white/85">
                Publish a public profile, manage appointments, walk-ins and queues in one place, and let patients book you directly.
              </p>
            </div>
            <div className="flex shrink-0 flex-wrap gap-2">
              <LinkButton href="/register" variant="light">
                Get started free
              </LinkButton>
              <LinkButton href="/hospitals" variant="glass">
                See live examples
              </LinkButton>
            </div>
          </div>
        </section>

        {hospitals.data.length > 0 ? (
          <section className="py-8">
            <SectionHeading
              title={"Hospitals & clinics"}
              action={
                <Link href="/hospitals" className="text-sm text-indigo no-underline">
                  See all
                </Link>
              }
            />
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              {hospitals.data.map((org) => (
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
          </section>
        ) : null}

        {doctors.data.length > 0 ? (
          <section className="py-8">
            <SectionHeading
              title="Doctors"
              action={
                <Link href="/doctors" className="text-sm text-indigo no-underline">
                  See all
                </Link>
              }
            />
            <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              {doctors.data.map((doctor) => (
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
          </section>
        ) : null}

        {hospitals.data.length === 0 && doctors.data.length === 0 ? (
          <p className="py-12 text-center text-sm text-ink-muted">
            No clinics have published their public profile yet — check back soon.
          </p>
        ) : null}
      </main>

      <footer className="border-t border-border bg-card">
        <div className="mx-auto flex max-w-5xl flex-col items-center justify-between gap-3 px-5 py-8 text-center sm:flex-row sm:text-left">
          <div className="flex items-center gap-2">
            <span
              className="inline-block h-6 w-6 rounded-md"
              style={{ background: "linear-gradient(135deg, var(--indigo), var(--coral))" }}
              aria-hidden
            />
            <span className="text-sm text-ink">© {new Date().getFullYear()} DoseWise</span>
          </div>
          <nav aria-label="Footer" className="flex flex-wrap items-center justify-center gap-5 text-sm">
            <Link href="/doctors" className="text-ink-muted no-underline hover:text-indigo">
              Find a doctor
            </Link>
            <Link href="/hospitals" className="text-ink-muted no-underline hover:text-indigo">
              Find a hospital
            </Link>
            <Link href="/register" className="text-ink-muted no-underline hover:text-indigo">
              For clinics
            </Link>
          </nav>
        </div>
      </footer>
    </div>
  );
}
