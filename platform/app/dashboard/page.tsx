import Link from "next/link";
import { requireWebUser } from "@/lib/web-context.js";
import { listMyOrganizations } from "@/modules/tenancy/service.js";
import { Button, EmptyState, LinkButton } from "@/components/ui/index.js";
import { logoutAction } from "../login/actions.js";
import { ClinicGrid, type ClinicCardData } from "./clinic-grid";

export const dynamic = "force-dynamic";

/**
 * The post-login hub: every clinic the signed-in user belongs to. Cards
 * collect the clinic's important details — type, city, verification, publish
 * state, live counts, and the same honest profile-completeness percentage the
 * onboarding checklist shows — with instant search/sort (client component).
 */
export default async function DashboardHome() {
  const ctx = await requireWebUser();
  const orgs = await listMyOrganizations(ctx);

  // Completeness is a plain object (safe to cross the server/client boundary);
  // dates must be serialized to ISO strings for the client sort.
  const cards: ClinicCardData[] = orgs.map((o) => ({
    id: o.id,
    name: o.name,
    slug: o.slug,
    orgType: o.orgType,
    tagline: o.tagline,
    isActive: o.isActive,
    isPubliclyListed: o.isPubliclyListed,
    verificationStatus: o.verificationStatus,
    role: o.role,
    city: o.location?.city ?? null,
    counts: o.counts,
    createdAt: o.createdAt.toISOString(),
    completeness: o.completeness,
  }));

  const verifiedCount = cards.filter((o) => o.verificationStatus === "VERIFIED").length;
  const publishedCount = cards.filter((o) => o.isPubliclyListed && o.isActive).length;
  const totalDoctors = cards.reduce((sum, o) => sum + o.counts.doctorProfiles, 0);

  return (
    <div className="min-h-screen bg-surface-2">
      {/* Compact top bar — the hub has no sidebar, so it carries its own chrome. */}
      <header className="border-b border-border bg-card">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-y-2 px-5 py-3 sm:h-16 sm:py-0">
          <Link href="/" className="flex items-center gap-2 no-underline">
            <span
              className="inline-block h-7 w-7 rounded-lg"
              style={{ background: "linear-gradient(135deg, var(--indigo), var(--coral))" }}
              aria-hidden
            />
            <strong className="text-sm text-ink">DoseWise</strong>
          </Link>
          <div className="flex items-center gap-3">
            {ctx.isPlatformAdmin ? (
              <Link href="/admin" className="text-sm text-ink no-underline hover:text-indigo">
                Admin panel
              </Link>
            ) : null}
            <form action={logoutAction}>
              <Button variant="ghost" size="sm" type="submit">
                Sign out
              </Button>
            </form>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-5xl px-5 pb-20">
        <div className="mt-10 flex flex-wrap items-center justify-between gap-3">
          <div>
            <h1 className="font-display text-2xl font-bold text-ink">Your clinics</h1>
            <p className="mt-1 text-sm text-ink-muted">
              Pick a clinic to open its dashboard — each card shows its live profile at a glance.
            </p>
          </div>
          <LinkButton href="/dashboard/new">+ New clinic</LinkButton>
        </div>

        {cards.length === 0 ? (
          <div className="mt-8">
            <EmptyState
              title="You're not part of a clinic yet"
              description="Create your clinic to publish a public profile, take bookings, and manage your queue — setup takes a few minutes."
              action={
                <LinkButton href="/dashboard/new" className="mt-2">
                  Create your first clinic
                </LinkButton>
              }
            />
          </div>
        ) : (
          <>
            {/* Portfolio-at-a-glance summary for multi-clinic users. */}
            <div className="mt-6 grid grid-cols-2 gap-4 sm:grid-cols-4">
              {[
                { label: "Clinics", value: cards.length, tone: "indigo" as const },
                { label: "Verified", value: verifiedCount, tone: "ok" as const },
                { label: "Published", value: publishedCount, tone: "coral" as const },
                { label: "Doctors", value: totalDoctors, tone: "neutral" as const },
              ].map((t) => (
                <div key={t.label} className="rounded-card border border-border bg-card px-5 py-4">
                  <div className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">
                    {t.label}
                  </div>
                  <div
                    className={`mt-1 font-display text-2xl font-bold tabular-nums ${
                      t.tone === "ok" ? "text-ok" : t.tone === "coral" ? "text-coral" : "text-ink"
                    }`}
                  >
                    {t.value}
                  </div>
                </div>
              ))}
            </div>

            <ClinicGrid orgs={cards} />
          </>
        )}
      </main>
    </div>
  );
}
