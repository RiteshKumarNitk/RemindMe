import Link from "next/link";
import { notFound } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { getPublicOrganization } from "@/modules/public/service.js";
import { Badge, Card, CardSubtitle, CardTitle, EmptyState } from "@/components/ui/index.js";
import { PublicHeader } from "../../public-header";

export const dynamic = "force-dynamic";

export default async function HospitalDetailPage({
  params,
}: {
  params: Promise<{ slug: string }>;
}) {
  const { slug } = await params;

  let org: Awaited<ReturnType<typeof getPublicOrganization>>;
  try {
    org = await getPublicOrganization(slug);
  } catch (err) {
    if (err instanceof AppError && err.code === "NOT_FOUND") notFound();
    throw err;
  }

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-5xl px-5 py-10">
        <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
          <div>
            <h1 className="text-2xl font-semibold text-ink">{org.name}</h1>
            {org.tagline ? <p className="mt-1 text-sm text-ink-muted">{org.tagline}</p> : null}
            <div className="mt-2 flex flex-wrap items-center gap-2">
              {org.orgType ? <Badge tone="neutral">{org.orgType.replace(/_/g, " ")}</Badge> : null}
              <Badge tone={org.verificationStatus === "VERIFIED" ? "indigo" : "neutral"}>
                {org.verificationStatus === "VERIFIED" ? "Verified" : "Not verified yet"}
              </Badge>
            </div>
          </div>
        </div>

        {org.about ? <p className="mt-6 max-w-2xl text-sm text-ink">{org.about}</p> : null}

        <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
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

        <h2 className="mt-10 text-lg font-semibold text-ink">Doctors</h2>
        {org.doctorProfiles.length === 0 ? (
          <div className="mt-4">
            <EmptyState title="No doctors listed yet" />
          </div>
        ) : (
          <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
            {org.doctorProfiles.map((doctor) => (
              <Link key={doctor.id} href={`/doctors/${doctor.id}`} className="no-underline">
                <Card className="h-full transition-colors hover:border-indigo">
                  <CardTitle>{doctor.displayName}</CardTitle>
                  <CardSubtitle className="mt-1">
                    {doctor.specialty ?? "General practice"}
                    {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} yrs` : ""}
                  </CardSubtitle>
                </Card>
              </Link>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
