import Link from "next/link";
import { notFound } from "next/navigation";
import { AppError } from "@/lib/errors.js";
import { getPublicDoctor } from "@/modules/public/service.js";
import { Badge, Card, CardSubtitle, CardTitle } from "@/components/ui/index.js";
import { PublicHeader } from "../../public-header";

export const dynamic = "force-dynamic";

function formatFee(minor: number | null): string | null {
  if (minor == null) return null;
  return (minor / 100).toLocaleString(undefined, { minimumFractionDigits: 0, maximumFractionDigits: 2 });
}

export default async function DoctorDetailPage({
  params,
}: {
  params: Promise<{ doctorId: string }>;
}) {
  const { doctorId } = await params;

  let doctor: Awaited<ReturnType<typeof getPublicDoctor>>;
  try {
    doctor = await getPublicDoctor(doctorId);
  } catch (err) {
    if (err instanceof AppError && err.code === "NOT_FOUND") notFound();
    throw err;
  }

  const fee = formatFee(doctor.consultationFeeMinor);

  return (
    <div>
      <PublicHeader />
      <main className="mx-auto max-w-3xl px-5 py-10">
        <div className="flex items-start gap-4">
          <div className="flex-1">
            <h1 className="text-2xl font-semibold text-ink">{doctor.displayName}</h1>
            <p className="mt-1 text-sm text-ink-muted">
              {doctor.specialty ?? "General practice"}
              {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} years experience` : ""}
            </p>
            {doctor.qualifications ? (
              <p className="mt-1 text-sm text-ink-muted">{doctor.qualifications}</p>
            ) : null}
            {doctor.languages.length ? (
              <p className="mt-1 text-sm text-ink-muted">{doctor.languages.join(" · ")}</p>
            ) : null}
          </div>
          {fee ? <Badge tone="indigo">₹{fee} / visit</Badge> : null}
        </div>

        {doctor.bio ? <p className="mt-6 text-sm text-ink">{doctor.bio}</p> : null}

        {doctor.registrationNumber ? (
          <p className="mt-4 text-xs text-ink-muted">Registration: {doctor.registrationNumber}</p>
        ) : null}

        <Card className="mt-8">
          <CardSubtitle>Practices at</CardSubtitle>
          <Link href={`/hospitals/${doctor.organization.slug}`} className="mt-1 block no-underline">
            <CardTitle>{doctor.organization.name}</CardTitle>
          </Link>
          {doctor.organization.locations.length > 0 ? (
            <div className="mt-3 flex flex-col gap-1 text-sm text-ink-muted">
              {doctor.organization.locations.map((loc) => (
                <span key={loc.id}>
                  {loc.name}
                  {loc.city ? ` — ${loc.city}` : ""}
                </span>
              ))}
            </div>
          ) : null}
        </Card>

        <div className="mt-8 rounded-[var(--radius-card)] border border-dashed border-border p-5 text-sm text-ink-muted">
          Online booking isn&rsquo;t live yet — this is next on the roadmap. In the meantime,
          contact {doctor.organization.name} directly to book an appointment.
        </div>
      </main>
    </div>
  );
}
