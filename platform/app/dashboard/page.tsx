import Link from "next/link";
import { requireWebUser } from "@/lib/web-context.js";
import { listMyOrganizations } from "@/modules/tenancy/service.js";
import {
  Badge,
  Button,
  EmptyState,
  InitialsAvatar,
  LinkButton,
} from "@/components/ui/index.js";
import { logoutAction } from "../login/actions.js";

export const dynamic = "force-dynamic";

const ROLE_LABEL: Record<string, string> = {
  CLINIC_ADMIN: "Admin",
  RECEPTION: "Reception",
  DOCTOR: "Doctor",
};

/**
 * The post-login hub: every clinic the signed-in user belongs to, one card
 * each, with a direct path into onboarding when they have none. Replaces the
 * old inline-styled page with the shared design kit.
 */
export default async function DashboardHome() {
  const ctx = await requireWebUser();
  const orgs = await listMyOrganizations(ctx);

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
              Pick a clinic to open its dashboard, or create a new one.
            </p>
          </div>
          <LinkButton href="/dashboard/new">+ New clinic</LinkButton>
        </div>

        {orgs.length === 0 ? (
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
          <div className="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {orgs.map((o) => (
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
                      <p className="truncate text-[12px] text-ink-faint">{o.slug}</p>
                    </div>
                  </div>
                  <div className="mt-auto flex flex-wrap items-center gap-2">
                    <Badge tone={o.role === "CLINIC_ADMIN" ? "coral" : "indigo"}>
                      {ROLE_LABEL[o.role] ?? o.role}
                    </Badge>
                    {!o.isActive ? <Badge tone="warn">Deactivated</Badge> : null}
                  </div>
                </div>
              </Link>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
