export default function Home() {
  return (
    <main style={{ fontFamily: "system-ui", padding: 32 }}>
      <h1>DoseWise Platform</h1>
      <p>
        API backend (Phase 1). The web application ships in Phase 4. See{" "}
        <code>platform/docs/</code>.
      </p>
      <p>
        Health check: <a href="/api/health">/api/health</a>
      </p>
    </main>
  );
}
