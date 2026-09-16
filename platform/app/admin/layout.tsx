import type { ReactNode } from "react";
import Link from "next/link";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { NavLink } from "@/components/nav-link.js";
import { Badge, Button } from "../dashboard/ui.js";
import { logoutAction } from "../login/actions.js";

export const dynamic = "force-dynamic";

const NAV = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/organizations", label: "Clinics" },
  { href: "/admin/verification", label: "Verification" },
  { href: "/admin/audit", label: "Audit log" },
];

export default async function AdminLayout({ children }: { children: ReactNode }) {
  await requireSuperAdmin();

  const navLinkStyle = { padding: "8px 10px", borderRadius: 8, fontSize: 14, textDecoration: "none", color: "var(--ink)" };

  return (
    <div className="dashboard-shell">
      <a href="#main-content" className="skip-link">
        Skip to content
      </a>
      <aside className="dashboard-sidebar">
        <Link href="/admin" style={{ textDecoration: "none", color: "inherit", marginBottom: 20 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <span
              style={{
                width: 24,
                height: 24,
                borderRadius: 7,
                background: "linear-gradient(135deg, var(--indigo), var(--coral))",
              }}
              aria-hidden
            />
            <strong style={{ fontSize: 14 }}>DoseWise</strong>
          </div>
        </Link>

        <div style={{ marginBottom: 20 }}>
          <Badge tone="coral">SUPER_ADMIN</Badge>
        </div>

        <nav className="dashboard-nav" aria-label="Admin">
          {NAV.map((item) => (
            <NavLink key={item.href} href={item.href} exact={item.href === "/admin"} style={navLinkStyle}>
              {item.label}
            </NavLink>
          ))}
          <Link
            href="/dashboard"
            style={{ padding: "8px 10px", borderRadius: 8, fontSize: 14, textDecoration: "none", color: "var(--ink-muted)" }}
          >
            ← Back to clinics
          </Link>
        </nav>

        <form action={logoutAction}>
          <Button variant="ghost" type="submit">
            Sign out
          </Button>
        </form>
      </aside>
      <main id="main-content" className="dashboard-main">
        {children}
      </main>
    </div>
  );
}
