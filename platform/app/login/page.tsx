import Link from "next/link";
import { redirect } from "next/navigation";
import { optionalWebUser } from "@/lib/web-context.js";
import { safeNextPath } from "@/lib/safe-redirect.js";
import { googleOAuthConfigured } from "@/lib/env.js";
import { Button, Card, CardTitle, Field, Input, Notice } from "@/components/ui/index.js";
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
    <main className="flex min-h-[80vh] flex-col items-center justify-center px-5 py-12">
      <div className="w-full max-w-sm">
        <Link href="/" className="mb-7 flex items-center gap-2.5 no-underline">
          <span
            className="inline-block h-8 w-8 rounded-lg"
            style={{ background: "linear-gradient(135deg, var(--indigo), var(--coral))" }}
            aria-hidden
          />
          <strong className="text-base text-ink">DoseWise</strong>
        </Link>

        <Card>
          <CardTitle as="h1" className="text-lg">Sign in</CardTitle>
          <p className="mt-1 text-sm text-ink-muted">
            New here?{" "}
            <Link
              href={next ? `/register?next=${encodeURIComponent(next)}` : "/register"}
              className="text-indigo"
            >
              Create an account
            </Link>
          </p>

          {error ? <div className="mt-4"><Notice tone="down">{error}</Notice></div> : null}

          <form action={loginAction} className="mt-5 flex flex-col gap-4">
            {next ? <input type="hidden" name="next" value={next} /> : null}
            <Field label="Email">
              <Input name="email" type="email" autoComplete="email" required className="w-full" />
            </Field>
            <Field label="Password">
              <Input name="password" type="password" autoComplete="current-password" required className="w-full" />
            </Field>
            <Button type="submit" size="lg" className="w-full">Sign in</Button>
          </form>

          {googleOAuthConfigured ? (
            <>
              <div className="my-5 flex items-center gap-3" aria-hidden>
                <span className="h-px flex-1 bg-border" />
                <span className="text-xs text-ink-muted">or</span>
                <span className="h-px flex-1 bg-border" />
              </div>
              <a
                href="/api/auth/google/start"
                className="flex h-11 w-full items-center justify-center gap-2.5 rounded-control border border-border bg-card text-sm font-medium text-ink no-underline hover:bg-surface"
              >
                <svg aria-hidden viewBox="0 0 18 18" className="h-4.5 w-4.5">
                  <path fill="#4285F4" d="M17.64 9.2c0-.64-.06-1.25-.16-1.84H9v3.48h4.84a4.14 4.14 0 0 1-1.8 2.72v2.26h2.92a8.78 8.78 0 0 0 2.68-6.62Z" />
                  <path fill="#34A853" d="M9 18c2.43 0 4.47-.8 5.96-2.18l-2.92-2.26a5.4 5.4 0 0 1-8.09-2.85H.96v2.33A9 9 0 0 0 9 18Z" />
                  <path fill="#FBBC05" d="M3.96 10.71a5.41 5.41 0 0 1 0-3.42V4.96H.96a9 9 0 0 0 0 8.08l3-2.33Z" />
                  <path fill="#EA4335" d="M9 3.58c1.32 0 2.5.45 3.44 1.35l2.58-2.59A9 9 0 0 0 .96 4.96l3 2.33A5.36 5.36 0 0 1 9 3.58Z" />
                </svg>
                Continue with Google
              </a>
            </>
          ) : null}
        </Card>

        <p className="mt-6 text-center text-sm text-ink-muted">
          Just browsing? The doctor and hospital directory is open to everyone.
        </p>
      </div>
    </main>
  );
}
