import { cache } from "react";
import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { getPublicOrganization } from "@/modules/public/service.js";
import {
  Badge,
  Card,
  CardSubtitle,
  CardTitle,
  EmptyState,
  HospitalDoctorCard,
  VerificationBadge,
} from "@/components/ui/index.js";
import { PublicHeader } from "../../public-header";

export const dynamic = "force-dynamic";

// Cached per-request so generateMetadata and the page component share one
// DB lookup instead of two (getPublicOrganization is a direct Prisma call,
// not `fetch()`, so it isn't deduped automatically the way fetch() would be).
const loadOrg = cache(async (slug: string) => {
  try {
    return await getPublicOrganization(slug);
  } catch (err) {
    if (err instanceof AppError && err.code === "NOT_FOUND") return null;
    throw err;
  }
});

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }): Promise<Metadata> {
  const { slug } = await params;
  const org = await loadOrg(slug);
  if (!org) return { title: "Clinic not found | DoseWise" };
  return {
    title: `${org.name} | DoseWise`,
    description: org.tagline ?? org.about ?? `${org.name} on DoseWise — view doctors and book an appointment.`,
  };
}

const ORG_TYPE_LABEL: Record<string, string> = {
  HOSPITAL: "Hospital",
  CLINIC: "Clinic",
  POLYCLINIC: "Polyclinic",
  DIAGNOSTIC_CENTER: "Diagnostic centre",
  OTHER: "Healthcare provider",
};

export default async function HospitalDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  const org = await loadOrg(slug);
  if (!org) notFound();

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 py-10">
        {/* Identity header — logo block, name, type, verification. Rendered
            even when a cover image exists; the gradient block stands in for
            the logo until real logo files are uploaded. */}
        <div className="overflow-hidden rounded-card border border-border bg-card">
          {org.coverImageUrl ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={org.coverImageUrl}
              alt=""
              className="h-40 w-full object-cover sm:h-56"
              loading="eager"
            />
          ) : (
            <div
              className="h-20 w-full"
              style={{ background: "linear-gradient(135deg, var(--indigo), var(--coral))" }}
              aria-hidden
            />
          )}
          <div className="flex flex-col gap-4 p-5 sm:flex-row sm:items-start">
            <div
              className="flex h-16 w-16 shrink-0 items-center justify-center rounded-card border border-border bg-surface font-display text-xl font-bold text-ink"
              aria-hidden
            >
              {org.name.trim().charAt(0).toUpperCase()}
            </div>
            <div className="min-w-0 flex-1">
              <h1 className="text-2xl font-semibold text-ink">{org.name}</h1>
              {org.tagline ? <p className="mt-1 text-sm text-ink-muted">{org.tagline}</p> : null}
              <div className="mt-2 flex flex-wrap items-center gap-2">
                {org.orgType ? (
                  <Badge tone="neutral">{ORG_TYPE_LABEL[org.orgType] ?? org.orgType.replace(/_/g, " ")}</Badge>
                ) : null}
                <VerificationBadge verified={org.verificationStatus === "VERIFIED"} />
                <Badge tone="indigo">
                  {org.doctorProfiles.length} {org.doctorProfiles.length === 1 ? "doctor" : "doctors"}
                </Badge>
              </div>
            </div>
          </div>
        </div>

        {org.about ? (
          <section className="mt-8">
            <h2 className="text-lg font-semibold text-ink">About</h2>
            <p className="mt-2 max-w-2xl text-sm text-ink">{org.about}</p>
          </section>
        ) : null}

        <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2">
          {org.publicPhone || org.publicEmail || org.website ? (
            <Card>
              <CardSubtitle>Contact</CardSubtitle>
              <div className="mt-2 flex flex-col gap-1 text-sm text-ink">
                {org.publicPhone ? <span>{org.publicPhone}</span> : null}
                {org.publicEmail ? <span>{org.publicEmail}</span> : null}
                {org.website ? (
                  <a href={org.website} className="text-indigo no-underline" target="_blank" rel="noreferrer">
                    {org.website}
                  </a>
                ) : null}
              </div>
            </Card>
          ) : null}

          {org.locations.length > 0 ? (
            <Card>
              <CardSubtitle>Locations</CardSubtitle>
              <div className="mt-2 flex flex-col gap-3 text-sm text-ink">
                {org.locations.map((loc) => (
                  <div key={loc.id}>
                    <div className="font-medium">{loc.name}</div>
                    <div className="text-ink-muted">
                      {[loc.addressLine1, loc.city, loc.state].filter(Boolean).join(", ") || "—"}
                    </div>
                  </div>
                ))}
              </div>
            </Card>
          ) : null}
        </div>

        <section className="mt-10">
          <h2 className="text-lg font-semibold text-ink">Doctors</h2>
          {org.doctorProfiles.length === 0 ? (
            <div className="mt-4">
              <EmptyState
                title="No doctors listed yet"
                description="This clinic hasn't published any doctors on DoseWise."
              />
            </div>
          ) : (
            <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
              {org.doctorProfiles.map((doctor) => (
                <HospitalDoctorCard
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
                    organization: { name: org.name, slug: org.slug },
                  }}
                />
              ))}
            </div>
          )}
        </section>
      </main>
    </div>
  );
}
