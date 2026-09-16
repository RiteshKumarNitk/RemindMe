import type { ReactNode } from "react";
import Link from "next/link";
import { db } from "@/lib/db.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { Badge, Button } from "../ui.js";
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

export default async function OrgLayout({
  children,
  params,
}: {
  children: ReactNode;
  params: Promise<{ orgId: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const org = await db.organization.findUniqueOrThrow({
    where: { id: orgId },
    select: { name: true },
  });

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

  const items = NAV[ctx.org!.role] ?? [];

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
        <Link href="/dashboard" style={{ textDecoration: "none", color: "inherit", marginBottom: 20 }}>
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

        <div style={{ marginBottom: 4, fontWeight: 700, fontSize: 14 }}>{org.name}</div>
        <div style={{ marginBottom: 20 }}>
          <Badge tone={ctx.org!.role === "CLINIC_ADMIN" ? "coral" : "indigo"}>{ctx.org!.role}</Badge>
        </div>

        <nav style={{ display: "flex", flexDirection: "column", gap: 2, flex: 1 }}>
          {items.map((item) => (
            <Link
              key={item.label}
              href={`/dashboard/${orgId}${item.href}`}
              style={{
                padding: "8px 10px",
                borderRadius: 8,
                fontSize: 14,
                textDecoration: "none",
                color: "var(--ink)",
              }}
            >
              {item.label}
            </Link>
          ))}
          {doctorProfileHref && (
            <Link
              href={doctorProfileHref}
              style={{ padding: "8px 10px", borderRadius: 8, fontSize: 14, textDecoration: "none", color: "var(--ink)" }}
            >
              My profile
            </Link>
          )}
          {doctorHref && (
            <Link
              href={doctorHref}
              style={{ padding: "8px 10px", borderRadius: 8, fontSize: 14, textDecoration: "none", color: "var(--ink)" }}
            >
              My availability
            </Link>
          )}
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
