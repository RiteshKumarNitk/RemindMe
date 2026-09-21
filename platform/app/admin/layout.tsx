import type { ReactNode } from "react";
import Link from "next/link";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { NavLink } from "@/components/nav-link.js";
import { navIconFor, LogOutIcon } from "@/components/dashboard-icons.js";
import { MobileNavAside, MobileNavButton, MobileNavProvider } from "@/components/mobile-nav.js";
import { Badge } from "@/components/ui/index.js";
import { logoutAction } from "../login/actions.js";

export const dynamic = "force-dynamic";

const NAV = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/organizations", label: "Clinics" },
  { href: "/admin/verification", label: "Verification" },
  { href: "/admin/audit", label: "Audit log" },
];

const navLinkClass =
  "flex items-center gap-2.5 rounded-xl px-2.5 py-2 text-[13.5px] font-medium text-ink-muted no-underline hover:bg-surface-2 hover:text-ink aria-[current=page]:bg-indigo/10 aria-[current=page]:font-semibold aria-[current=page]:text-indigo-dark [&_svg]:h-4.25 [&_svg]:w-4.25 [&_svg]:shrink-0 [&_svg]:opacity-80 aria-[current=page]:[&_svg]:opacity-100";

export default async function AdminLayout({ children }: { children: ReactNode }) {
  await requireSuperAdmin();

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
          <Link href="/admin" className="mb-5 flex items-center gap-2 px-2 pt-1.5 no-underline">
            <span className="h-7 w-7 shrink-0 rounded-lg bg-linear-to-br from-indigo to-coral" aria-hidden />
            <strong className="font-display text-[15px] text-ink">DoseWise</strong>
          </Link>

          <div className="mb-5 px-2">
            <Badge tone="coral">SUPER_ADMIN</Badge>
          </div>

          <nav className="flex flex-1 flex-col gap-0.5" aria-label="Admin">
            {NAV.map((item) => {
              const NavIcon = navIconFor(item.label);
              return (
                <NavLink key={item.href} href={item.href} exact={item.href === "/admin"} className={navLinkClass}>
                  <NavIcon />
                  {item.label}
                </NavLink>
              );
            })}
            <Link href="/dashboard" className={`${navLinkClass} mt-2 border-t border-border pt-3`}>
              ← Back to clinics
            </Link>
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
            <strong className="font-display text-[15px] text-ink md:hidden">DoseWise Admin</strong>
          </header>
          <main id="main-content" className="mx-auto w-full max-w-7xl flex-1 px-9 py-8 max-md:px-4 max-md:py-5">
            {children}
          </main>
        </div>
      </div>
    </MobileNavProvider>
  );
}
