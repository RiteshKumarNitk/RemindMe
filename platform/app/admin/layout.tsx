import type { ReactNode } from "react";
import Link from "next/link";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { Badge, Button } from "../dashboard/ui.js";
import { logoutAction } from "../login/actions.js";

export const dynamic = "force-dynamic";

const NAV = [
  { href: "/admin", label: "Overview" },
  { href: "/admin/organizations", label: "Clinics" },
  { href: "/admin/audit", label: "Audit log" },
];

export default async function AdminLayout({ children }: { children: ReactNode }) {
  await requireSuperAdmin();

  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      <aside
        style={{
          width: 220,
          flexShrink: 0,
          borderRight: "1px solid var(--border)",
          padding: "24px 16px",
          display: "flex",
          flexDirection: "column",
        }}
      >
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

        <nav style={{ display: "flex", flexDirection: "column", gap: 2, flex: 1 }}>
          {NAV.map((item) => (
            <Link
              key={item.href}
              href={item.href}
              style={{ padding: "8px 10px", borderRadius: 8, fontSize: 14, textDecoration: "none", color: "var(--ink)" }}
            >
              {item.label}
            </Link>
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
      <main style={{ flex: 1, padding: "32px 40px", maxWidth: 980 }}>{children}</main>
    </div>
  );
}
