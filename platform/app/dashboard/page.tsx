import Link from "next/link";
import { requireWebUser } from "@/lib/web-context.js";
import { listMyOrganizations } from "@/modules/tenancy/service.js";
import { Badge, Button, Card, EmptyState } from "./ui.js";
import { logoutAction } from "../login/actions.js";

export const dynamic = "force-dynamic";

export default async function DashboardHome() {
  const ctx = await requireWebUser();
  const orgs = await listMyOrganizations(ctx);

  return (
    <main style={{ maxWidth: 640, margin: "0 auto", padding: "56px 20px 80px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 28 }}>
        <div style={{ display: "inline-flex", alignItems: "center", gap: 10 }}>
          <span
            style={{
              width: 32,
              height: 32,
              borderRadius: 9,
              background: "linear-gradient(135deg, var(--indigo), var(--coral))",
            }}
            aria-hidden
          />
          <strong style={{ fontSize: 18 }}>DoseWise Platform</strong>
        </div>
        <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
          {ctx.isPlatformAdmin && (
            <Link href="/admin" style={{ fontSize: 13, fontWeight: 700 }}>
              Admin panel
            </Link>
          )}
          <form action={logoutAction}>
            <Button variant="ghost" type="submit">
              Sign out
            </Button>
          </form>
        </div>
      </div>

      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 14 }}>
        <h1 style={{ fontSize: 22, margin: 0 }}>Your clinics</h1>
        <Link href="/dashboard/new" style={{ fontSize: 13, fontWeight: 700 }}>
          + New clinic
        </Link>
      </div>

      {orgs.length === 0 ? (
        <Card>
          <EmptyState>
            You&rsquo;re not part of a clinic yet. <Link href="/dashboard/new">Create one</Link>{" "}
            to get started.
          </EmptyState>
        </Card>
      ) : (
        <div style={{ display: "grid", gap: 10 }}>
          {orgs.map((o) => (
            <Link key={o.id} href={`/dashboard/${o.id}`} style={{ textDecoration: "none", color: "inherit" }}>
              <Card style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <div style={{ fontWeight: 700 }}>{o.name}</div>
                  <div style={{ fontSize: 12, color: "var(--ink-muted)" }}>{o.slug}</div>
                </div>
                <Badge tone={o.role === "CLINIC_ADMIN" ? "coral" : "indigo"}>{o.role}</Badge>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </main>
  );
}
