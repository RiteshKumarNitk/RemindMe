import Link from "next/link";
import { redirect } from "next/navigation";
import { optionalWebUser } from "@/lib/web-context.js";
import { safeNextPath } from "@/lib/safe-redirect.js";
import { Button, Card, ErrorNote, Field } from "../dashboard/ui.js";
import { registerAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function RegisterPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; next?: string }>;
}) {
  const { error, next } = await searchParams;
  if (await optionalWebUser()) redirect(safeNextPath(next));

  return (
    <main style={{ maxWidth: 400, margin: "80px auto", padding: "0 20px" }}>
      <div style={{ display: "inline-flex", alignItems: "center", gap: 10, marginBottom: 28 }}>
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
      <Card>
        <h1 style={{ fontSize: 20, margin: "0 0 18px" }}>Create an account</h1>
        <ErrorNote message={error} />
        <form action={registerAction}>
          {next ? <input type="hidden" name="next" value={next} /> : null}
          <Field label="Full name" name="fullName" required />
          <Field label="Email" name="email" type="email" required />
          <Field label="Password" name="password" type="password" required placeholder="At least 10 characters" />
          <div style={{ marginTop: 8 }}>
            <Button>Create account</Button>
          </div>
        </form>
      </Card>
      <p style={{ marginTop: 16, fontSize: 13, color: "var(--ink-muted)" }}>
        Already have an account?{" "}
        <Link href={next ? `/login?next=${encodeURIComponent(next)}` : "/login"}>Sign in</Link>
      </p>
    </main>
  );
}
