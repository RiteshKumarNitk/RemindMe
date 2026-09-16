import Link from "next/link";
import { redirect } from "next/navigation";
import { optionalWebUser } from "@/lib/web-context.js";
import { safeNextPath } from "@/lib/safe-redirect.js";
import { Button, Card, ErrorNote, Field } from "../dashboard/ui.js";
import { loginAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function LoginPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; next?: string }>;
}) {
  const { error, next } = await searchParams;
  if (await optionalWebUser()) redirect(safeNextPath(next));

  return (
    <main style={{ maxWidth: 400, margin: "80px auto", padding: "0 20px" }}>
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
        <h1 style={{ fontSize: 20, margin: "0 0 18px" }}>Sign in</h1>
        <ErrorNote message={error} />
        <form action={loginAction}>
          {next ? <input type="hidden" name="next" value={next} /> : null}
          <Field label="Email" name="email" type="email" required />
          <Field label="Password" name="password" type="password" required />
          <div style={{ marginTop: 8 }}>
            <Button>Sign in</Button>
          </div>
        </form>
      </Card>
      <p style={{ marginTop: 16, fontSize: 13, color: "var(--ink-muted)" }}>
        New here?{" "}
        <Link href={next ? `/register?next=${encodeURIComponent(next)}` : "/register"}>
          Create an account
        </Link>
      </p>
    </main>
  );
}
