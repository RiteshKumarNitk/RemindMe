"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import type { Completeness } from "@/modules/clinics/completeness.js";
import { orgTypeLabel } from "@/modules/clinics/completeness.js";
import {
  Badge,
  EmptyState,
  InitialsAvatar,
  Input,
  Select,
  statusLabel,
  statusTone,
} from "@/components/ui/index.js";
import { CompletionMeter } from "@/components/ui/completion-meter.js";

const ROLE_LABEL: Record<string, string> = {
  CLINIC_ADMIN: "Admin",
  RECEPTION: "Reception",
  DOCTOR: "Doctor",
};

export interface ClinicCardData {
  id: string;
  name: string;
  slug: string;
  orgType: string | null;
  tagline: string | null;
  isActive: boolean;
  isPubliclyListed: boolean;
  verificationStatus: string;
  role: string;
  city: string | null;
  counts: { doctorProfiles: number; appointmentTypes: number; locations: number };
  createdAt: string; // ISO — serialized across the server/client boundary
  completeness: Completeness;
}

type SortKey = "newest" | "oldest" | "name" | "setup";

const SORTS: Array<{ value: SortKey; label: string }> = [
  { value: "newest", label: "Newest first" },
  { value: "oldest", label: "Oldest first" },
  { value: "name", label: "Name A–Z" },
  { value: "setup", label: "Needs setup first" },
];

/**
 * The clinic list on the post-login hub. Client-side so search and sort are
 * instant — the full portfolio is small (a user's own clinics), so filtering
 * in the browser beats a round trip per keystroke. The completion meter is the
 * same shared `Completeness` object the onboarding checklist uses, so the
 * percentage never disagrees between surfaces.
 */
export function ClinicGrid({ orgs }: { orgs: ClinicCardData[] }) {
  const [query, setQuery] = useState("");
  const [sort, setSort] = useState<SortKey>("newest");

  const visible = useMemo(() => {
    const q = query.trim().toLowerCase();
    const filtered = q
      ? orgs.filter(
          (o) =>
            o.name.toLowerCase().includes(q) ||
            o.slug.toLowerCase().includes(q) ||
            (o.city ?? "").toLowerCase().includes(q),
        )
      : orgs;
    const sorted = [...filtered];
    switch (sort) {
      case "oldest":
        sorted.sort((a, b) => a.createdAt.localeCompare(b.createdAt));
        break;
      case "name":
        sorted.sort((a, b) => a.name.localeCompare(b.name));
        break;
      case "setup":
        sorted.sort(
          (a, b) => a.completeness.percent - b.completeness.percent || a.name.localeCompare(b.name),
        );
        break;
      default:
        sorted.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
    }
    return sorted;
  }, [orgs, query, sort]);

  // The toolbar never unmounts — an empty result must not take the search box
  // with it, or the user is stranded on the empty state with no way to clear.
  return (
    <div className="mt-6">
      {/* Instant search + sort over the user's own clinics. */}
      <div className="flex flex-wrap items-center gap-2">
        <Input
          type="search"
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search your clinics…"
          aria-label="Search your clinics"
          className="h-10 w-full max-w-xs"
        />
        <Select
          value={sort}
          onChange={(e) => setSort(e.target.value as SortKey)}
          aria-label="Sort clinics"
          className="w-44"
        >
          {SORTS.map((s) => (
            <option key={s.value} value={s.value}>
              {s.label}
            </option>
          ))}
        </Select>
        <span className="ml-auto text-[12px] text-ink-faint" aria-live="polite">
          {visible.length} of {orgs.length}
        </span>
      </div>

      {visible.length === 0 ? (
        <div className="mt-4">
          <EmptyState
            title="No clinics match your search"
            description={`Nothing here matches “${query.trim()}”. Try a different name or city.`}
            action={
              <button
                type="button"
                onClick={() => setQuery("")}
                className="mt-2 cursor-pointer rounded-xl border border-border bg-card px-4 py-2.5 text-sm font-semibold text-ink"
              >
                Clear search
              </button>
            }
          />
        </div>
      ) : (
      <div className="mt-4 grid grid-cols-1 gap-4 sm:grid-cols-2">
        {visible.map((o) => {
          const nextFix = o.completeness.missing[0];
          return (
            <Link
              key={o.id}
              href={`/dashboard/${o.id}`}
              className="group no-underline"
              aria-label={`Open ${o.name} dashboard`}
            >
              <div className="flex h-full flex-col gap-4 rounded-card border border-border bg-card p-5 transition-colors group-hover:border-indigo">
                <div className="flex items-start gap-3">
                  <InitialsAvatar name={o.name} size="md" />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold text-ink">{o.name}</p>
                    <p className="mt-0.5 truncate text-[12px] text-ink-faint">
                      {[orgTypeLabel(o.orgType), o.city].filter(Boolean).join(" · ") || o.slug}
                    </p>
                  </div>
                  <svg
                    aria-hidden
                    viewBox="0 0 16 16"
                    className="mt-1 h-4 w-4 shrink-0 text-ink-faint transition-colors group-hover:text-indigo"
                    fill="none"
                    stroke="currentColor"
                    strokeWidth="1.6"
                  >
                    <path d="m6 3 5 5-5 5" strokeLinecap="round" strokeLinejoin="round" />
                  </svg>
                </div>

                <div className="flex flex-wrap items-center gap-2">
                  <Badge tone={statusTone(o.verificationStatus)}>
                    {statusLabel(o.verificationStatus)}
                  </Badge>
                  <Badge tone={o.isPubliclyListed ? "ok" : "warn"}>
                    {o.isPubliclyListed ? "Published" : "Not published"}
                  </Badge>
                  {!o.isActive ? <Badge tone="down">Deactivated</Badge> : null}
                  <Badge tone={o.role === "CLINIC_ADMIN" ? "coral" : "indigo"}>
                    {ROLE_LABEL[o.role] ?? o.role}
                  </Badge>
                </div>

                {/* Live completeness — same number the setup checklist shows. */}
                <div>
                  <CompletionMeter completeness={o.completeness} compact />
                  {nextFix ? (
                    <p className="mt-1.5 text-[11.5px] text-ink-muted">
                      Next: {nextFix.label}
                    </p>
                  ) : null}
                </div>

                <div className="mt-auto grid grid-cols-3 gap-2 border-t border-border pt-3 text-center">
                  <div>
                    <div className="font-display text-base font-bold tabular-nums text-ink">
                      {o.counts.doctorProfiles}
                    </div>
                    <div className="text-[10.5px] uppercase tracking-wide text-ink-faint">
                      {o.counts.doctorProfiles === 1 ? "Doctor" : "Doctors"}
                    </div>
                  </div>
                  <div>
                    <div className="font-display text-base font-bold tabular-nums text-ink">
                      {o.counts.appointmentTypes}
                    </div>
                    <div className="text-[10.5px] uppercase tracking-wide text-ink-faint">
                      {o.counts.appointmentTypes === 1 ? "Appt type" : "Appt types"}
                    </div>
                  </div>
                  <div>
                    <div className="font-display text-base font-bold tabular-nums text-ink">
                      {o.counts.locations}
                    </div>
                    <div className="text-[10.5px] uppercase tracking-wide text-ink-faint">
                      {o.counts.locations === 1 ? "Branch" : "Branches"}
                    </div>
                  </div>
                </div>
              </div>
            </Link>
          );
        })}
      </div>
      )}
    </div>
  );
}
