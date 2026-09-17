import type { ReactNode } from "react";
import Link from "next/link";
import { db } from "@/lib/db.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { NavLink } from "@/components/nav-link.js";
import { NotificationBell } from "@/components/notification-bell.js";
import { navIconFor, LogOutIcon, SearchIcon } from "@/components/dashboard-icons.js";
import { MobileNavAside, MobileNavButton, MobileNavProvider } from "@/components/mobile-nav.js";
import { Badge } from "@/components/ui/index.js";
import { logoutAction } from "../../login/actions.js";

export const dynamic = "force-dynamic";

const NAV: Record<string, Array<{ href: string; label: string }>> = {
  CLINIC_ADMIN: [
    { href: "", label: "Overview" },
    { href: "/profile", label: "Profile" },
    { href: "/doctors", label: "Doctors" },
    { href: "/staff", label: "Staff" },
    { href: "/team", label: "Team" },
    { href: "/patients", label: "Patients" },
    { href: "/appointments", label: "Appointments" },
    { href: "/queue", label: "Queue" },
    { href: "/settings", label: "Settings" },
    { href: "/audit", label: "Audit log" },
  ],
  RECEPTIONIST: [
    { href: "", label: "Overview" },
    { href: "/patients", label: "Patients" },
    { href: "/appointments", label: "Appointments" },
    { href: "/queue", label: "Queue" },
  ],
  DOCTOR: [
    { href: "", label: "Overview" },
    { href: "/appointments", label: "Appointments" },
    { href: "/queue", label: "Queue" },
  ],
  PATIENT: [
    { href: "", label: "Overview" },
    { href: "/appointments", label: "My appointments" },
    { href: "/family", label: "Family access" },
  ],
};

const ROLE_BADGE: Record<string, "coral" | "indigo" | "ok" | "warn"> = {
  CLINIC_ADMIN: "coral",
  DOCTOR: "indigo",
  RECEPTIONIST: "ok",
  PATIENT: "warn",
};

function initials(name: string): string {
  const parts = name.trim().split(/\s+/);
  return ((parts[0]?.[0] ?? "") + (parts[1]?.[0] ?? "")).toUpperCase() || "?";
}

const navLinkClass =
  "flex items-center gap-2.5 rounded-xl px-2.5 py-2 text-[13.5px] font-medium text-ink-muted no-underline hover:bg-surface-2 hover:text-ink aria-[current=page]:bg-indigo/10 aria-[current=page]:font-semibold aria-[current=page]:text-indigo-dark [&_svg]:h-4.25 [&_svg]:w-4.25 [&_svg]:shrink-0 [&_svg]:opacity-80 aria-[current=page]:[&_svg]:opacity-100";

export default async function OrgLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ orgId: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const [org, user] = await Promise.all([
    db.organization.findUniqueOrThrow({ where: { id: orgId }, select: { name: true } }),
    db.user.findUniqueOrThrow({ where: { id: ctx.userId }, select: { fullName: true } }),
  ]);

  let doctorHref: string | null = null;
  let doctorProfileHref: string | null = null;
  if (ctx.org!.role === "DOCTOR") {
    const doctor = await db.doctorProfile.findFirst({
      where: { organizationId: orgId, userId: ctx.userId },
      select: { id: true },
    });
    if (doctor) {
      doctorHref = `/dashboard/${orgId}/doctors/${doctor.id}/availability`;
      doctorProfileHref = `/dashboard/${orgId}/doctors/${doctor.id}/profile`;
    }
  }

  const role = ctx.org!.role;
  const items = NAV[role] ?? [];

  return (
    <MobileNavProvider>
      <div className="flex min-h-screen bg-surface">
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:absolute focus:left-2 focus:top-2 focus:z-50 focus:rounded-lg focus:border focus:border-border focus:bg-card focus:px-4 focus:py-2.5 focus:text-sm focus:text-ink"
        >
          Skip to content
        </a>

        <MobileNavAside>
          <Link href="/dashboard" className="mb-5 flex items-center gap-2 px-2 pt-1.5 no-underline">
            <span className="h-7 w-7 shrink-0 rounded-lg bg-linear-to-br from-indigo to-coral" aria-hidden />
            <strong className="font-display text-[15px] text-ink">DoseWise</strong>
          </Link>

          <div className="mb-5 px-2">
            <div className="truncate text-sm font-semibold text-ink">{org.name}</div>
            <Badge tone={ROLE_BADGE[role] ?? "neutral"} className="mt-1.5">
              {role}
            </Badge>
          </div>

          <nav className="flex flex-1 flex-col gap-0.5" aria-label="Dashboard">
            {items.map((item) => {
              const NavIcon = navIconFor(item.label);
              return (
                <NavLink key={item.label} href={`/dashboard/${orgId}${item.href}`} exact={item.href === ""} className={navLinkClass}>
                  <NavIcon />
                  {item.label}
                </NavLink>
              );
            })}
            {doctorProfileHref && (
              <NavLink href={doctorProfileHref} className={navLinkClass}>
                {(() => {
                  const Icon = navIconFor("Profile");
                  return <Icon />;
                })()}
                My profile
              </NavLink>
            )}
            {doctorHref && (
              <NavLink href={doctorHref} className={navLinkClass}>
                {(() => {
                  const Icon = navIconFor("Queue");
                  return <Icon />;
                })()}
                My availability
              </NavLink>
            )}
          </nav>

          <form action={logoutAction} className="border-t border-border pt-2">
            <button
              type="submit"
              className="flex w-full items-center gap-2.5 rounded-xl px-2.5 py-2 text-[13.5px] font-medium text-ink-muted hover:bg-surface-2 hover:text-ink [&_svg]:h-4.25 [&_svg]:w-4.25"
            >
              <LogOutIcon />
              Sign out
            </button>
          </form>
        </MobileNavAside>

        <div className="flex min-w-0 flex-1 flex-col">
          <header className="sticky top-0 z-20 flex items-center gap-3 border-b border-border bg-surface/90 px-7 py-3 backdrop-blur-sm max-md:px-4">
            <MobileNavButton />
            <div className="hidden max-w-90 flex-1 items-center gap-2 rounded-full border border-border bg-card px-3.5 py-2 text-ink-faint sm:flex">
              <SearchIcon className="h-3.75 w-3.75 shrink-0" />
              <input
                type="search"
                placeholder="Search patients, doctors, appointments…"
                aria-label="Search"
                className="w-full border-0 bg-transparent text-sm text-ink outline-none placeholder:text-ink-muted"
              />
            </div>
            <div className="flex-1" />
            <NotificationBell orgId={orgId} />
            <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-linear-to-br from-indigo to-coral font-display text-[13px] font-bold text-white">
              {initials(user.fullName)}
            </div>
          </header>

          <main id="main-content" className="mx-auto w-full max-w-7xl flex-1 px-9 py-8 max-md:px-4 max-md:py-5">
            {children}
          </main>
        </div>
      </div>
    </MobileNavProvider>
  );
}
