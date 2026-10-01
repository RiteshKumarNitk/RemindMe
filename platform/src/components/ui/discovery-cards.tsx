import Link from "next/link";
import type { ReactNode } from "react";
import { Badge, Card, CardSubtitle, CardTitle } from "./index.js";
import { InitialsAvatar } from "./avatar.js";

/**
 * Shared discovery cards for /hospitals, /doctors and the homepage.
 *
 * Extracted because all three pages hand-rolled near-identical cards that had
 * drifted (homepage cards lacked the verification badge the hospital page's
 * lacked, etc.). They show ONLY fields the public API actually returns —
 * verificationStatus, photoUrl/logoUrl, consultationFeeMinor, years of
 * experience, doctor counts — and degrade to initials or omit rows rather
 * than inventing placeholder content.
 */

const ORG_TYPE_LABEL: Record<string, string> = {
  HOSPITAL: "Hospital",
  CLINIC: "Clinic",
  POLYCLINIC: "Polyclinic",
  DIAGNOSTIC_CENTER: "Diagnostic centre",
  OTHER: "Healthcare provider",
};

export function VerificationBadge({ verified }: { verified: boolean }) {
  return verified ? (
    <Badge tone="ok">
      <svg aria-hidden viewBox="0 0 16 16" className="h-3 w-3" fill="currentColor">
        <path
          fillRule="evenodd"
          d="M8 0l1.9 1.4 2.3-.3 1 2.1 2.1 1-.3 2.3L16 8l-1 1.9.3 2.3-2.1 1-1 2.1-2.3-.3L8 16l-1.9-1.4-2.3.3-1-2.1-2.1-1 .3-2.3L0 8l1-1.9-.3-2.3 2.1-1 1-2.1 2.3.3L8 0Zm3.7 6.3a1 1 0 0 0-1.4-1.4L7 8.2 5.7 6.9a1 1 0 1 0-1.4 1.4l2 2a1 1 0 0 0 1.4 0l4-4Z"
          clipRule="evenodd"
        />
      </svg>
      Verified
    </Badge>
  ) : null;
}

export interface PublicOrgCardData {
  name: string;
  slug: string;
  tagline: string | null;
  orgType: string | null;
  verificationStatus: string;
  logoUrl?: string | null;
  city: string | null;
  doctorCount: number;
}

export function HospitalCard({ org }: { org: PublicOrgCardData }) {
  return (
    <Link href={`/hospitals/${org.slug}`} className="group h-full no-underline">
      <Card className="flex h-full flex-col gap-2.5 transition-colors group-hover:border-indigo">
        <div className="flex items-start gap-3">
          <InitialsAvatar name={org.name} size="md" />
          <div className="min-w-0 flex-1">
            <CardTitle className="leading-snug">{org.name}</CardTitle>
            {org.city || org.tagline ? (
              <CardSubtitle className="mt-0.5 truncate">
                {org.city ?? org.tagline}
              </CardSubtitle>
            ) : null}
          </div>
        </div>
        <div className="mt-auto flex flex-wrap items-center gap-2">
          {org.orgType ? (
            <Badge tone="neutral">{ORG_TYPE_LABEL[org.orgType] ?? org.orgType.replace(/_/g, " ")}</Badge>
          ) : null}
          <VerificationBadge verified={org.verificationStatus === "VERIFIED"} />
          <Badge tone="indigo">
            {org.doctorCount} {org.doctorCount === 1 ? "doctor" : "doctors"}
          </Badge>
        </div>
      </Card>
    </Link>
  );
}

export interface PublicDoctorCardData {
  id: string;
  displayName: string;
  specialty: string | null;
  photoUrl?: string | null;
  yearsOfExperience: number | null;
  languages?: string[];
  consultationFeeMinor: number | null;
  organization: { name: string; slug: string };
  /** How patients book — drives the "Today's token" / "Scheduled" badge. */
  bookingMode?: "SCHEDULED" | "SAME_DAY_TOKEN" | "BOTH";
}

/** Public booking-method badge. Says how you book, never whether a token is
 *  still left today — that needs the live window, which the doctor page shows. */
export function BookingModeBadge({ mode }: { mode?: PublicDoctorCardData["bookingMode"] }) {
  if (mode === "SAME_DAY_TOKEN") return <Badge tone="coral">Same-day tokens</Badge>;
  if (mode === "BOTH") return <Badge tone="coral">Appointments · Same-day tokens</Badge>;
  if (mode === "SCHEDULED") return <Badge tone="neutral">Scheduled appointments</Badge>;
  return null;
}

export function DoctorCard({ doctor }: { doctor: PublicDoctorCardData }) {
  const fee =
    doctor.consultationFeeMinor != null
      ? `₹${(doctor.consultationFeeMinor / 100).toLocaleString(undefined, { maximumFractionDigits: 0 })}`
      : null;

  return (
    <Link href={`/doctors/${doctor.id}`} className="group h-full no-underline">
      <Card className="flex h-full flex-col gap-2.5 transition-colors group-hover:border-indigo">
        <div className="flex items-start gap-3">
          <InitialsAvatar name={doctor.displayName} size="md" />
          <div className="min-w-0 flex-1">
            <CardTitle className="leading-snug">{doctor.displayName}</CardTitle>
            <CardSubtitle className="mt-0.5">
              {doctor.specialty ?? "General practice"}
              {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} yrs` : ""}
            </CardSubtitle>
          </div>
        </div>
        <p className="truncate text-sm text-ink-muted">{doctor.organization.name}</p>
        <div className="mt-auto flex flex-wrap items-center gap-2">
          {fee ? <Badge tone="indigo">{fee} / visit</Badge> : null}
          <BookingModeBadge mode={doctor.bookingMode} />
          {doctor.languages?.length ? (
            <span className="truncate text-[11.5px] text-ink-faint">
              {doctor.languages.slice(0, 3).join(" · ")}
            </span>
          ) : null}
        </div>
      </Card>
    </Link>
  );
}

/** Compact "row" variant for the doctor grid on a hospital profile — photo
 * block, name, specialty, org column dropped (you're already there), Book
 * affordance instead of whole-card link. */
export function HospitalDoctorCard({ doctor }: { doctor: PublicDoctorCardData }) {
  const fee =
    doctor.consultationFeeMinor != null
      ? `₹${(doctor.consultationFeeMinor / 100).toLocaleString(undefined, { maximumFractionDigits: 0 })}`
      : null;

  return (
    <Card className="flex h-full flex-col gap-2.5">
      <div className="flex items-start gap-3">
        <InitialsAvatar name={doctor.displayName} size="md" />
        <div className="min-w-0 flex-1">
          <CardTitle className="leading-snug">{doctor.displayName}</CardTitle>
          <CardSubtitle className="mt-0.5">
            {doctor.specialty ?? "General practice"}
            {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} yrs` : ""}
          </CardSubtitle>
        </div>
      </div>
      <div className="flex flex-wrap gap-2">
        <BookingModeBadge mode={doctor.bookingMode} />
      </div>
      <div className="mt-auto flex items-center justify-between gap-2">
        {fee ? <Badge tone="indigo">{fee} / visit</Badge> : <span />}
        <Link
          href={`/doctors/${doctor.id}`}
          className="rounded-control border border-border px-3 py-1.5 text-sm font-medium text-indigo no-underline hover:bg-surface"
        >
          View &amp; book
        </Link>
      </div>
    </Card>
  );
}

/** Section header used by both discovery pages: title + "See all" link. */
export function SectionHeading({
  title,
  action,
}: {
  title: string;
  action?: ReactNode;
}) {
  return (
    <div className="mb-4 flex items-center justify-between gap-3">
      <h2 className="text-lg font-semibold text-ink">{title}</h2>
      {action}
    </div>
  );
}
