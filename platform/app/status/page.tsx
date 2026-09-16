import Link from "next/link";
import { StatusCard } from "../StatusCard";

const modules = [
  { name: "Auth", detail: "argon2id · JWT access/refresh · web sessions" },
  { name: "Tenancy & RBAC", detail: "org-scoped access, capability grants" },
  { name: "Clinics", detail: "locations, settings, staff & doctors" },
  { name: "Availability", detail: "recurring rules, exceptions, slot calc" },
  { name: "Appointments", detail: "booking, lifecycle, reschedule, cancel" },
  { name: "Queue", detail: "check-in tokens, call / recall / skip" },
  { name: "Public discovery", detail: "public organizations & doctors API" },
];

export default function StatusPage() {
  return (
    <main
      style={{
        maxWidth: 720,
        margin: "0 auto",
        padding: "64px 24px 80px",
      }}
    >
      <div
        style={{
          display: "inline-flex",
          alignItems: "center",
          gap: 10,
          marginBottom: 28,
        }}
      >
        <span
          style={{
            width: 36,
            height: 36,
            borderRadius: 10,
            background: "linear-gradient(135deg, var(--indigo), var(--coral))",
            display: "inline-block",
          }}
          aria-hidden
        />
        <strong style={{ fontSize: 20, letterSpacing: -0.2 }}>DoseWise Platform</strong>
      </div>

      <h1 style={{ fontSize: 34, lineHeight: 1.15, margin: "0 0 12px" }}>
        Multi-tenant healthcare
        <br />
        appointment &amp; patient API
      </h1>
      <p style={{ color: "var(--ink-muted)", fontSize: 16, maxWidth: 520, margin: "0 0 32px" }}>
        This is the backend status/engineering view. Looking for the patient-facing site?{" "}
        <Link href="/">Go to the homepage</Link>.
      </p>

      <StatusCard />

      <h2 style={{ fontSize: 15, textTransform: "uppercase", letterSpacing: 0.6, color: "var(--ink-muted)", margin: "40px 0 14px" }}>
        Shipped so far
      </h2>
      <div
        style={{
          display: "grid",
          gridTemplateColumns: "repeat(auto-fill, minmax(210px, 1fr))",
          gap: 12,
        }}
      >
        {modules.map((m) => (
          <div
            key={m.name}
            style={{
              background: "var(--card)",
              border: "1px solid var(--border)",
              borderRadius: 16,
              padding: "14px 16px",
            }}
          >
            <div style={{ fontWeight: 700, fontSize: 14 }}>{m.name}</div>
            <div style={{ color: "var(--ink-muted)", fontSize: 13, marginTop: 4 }}>
              {m.detail}
            </div>
          </div>
        ))}
      </div>

      <p style={{ marginTop: 40, fontSize: 13, color: "var(--ink-muted)" }}>
        API reference: <code>platform/docs/API.md</code> in the repo · Health
        check: <a href="/api/health">/api/health</a>
      </p>
    </main>
  );
}
