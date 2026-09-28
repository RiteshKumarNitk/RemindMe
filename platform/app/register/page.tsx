import Link from "next/link";
import { redirect } from "next/navigation";
import { optionalWebUser } from "@/lib/web-context.js";
import { safeNextPath } from "@/lib/safe-redirect.js";
import { Button, Card, CardTitle, Field, Input, Notice } from "@/components/ui/index.js";
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
          <CardTitle as="h1" className="text-lg">Create an account</CardTitle>
          <p className="mt-1 text-sm text-ink-muted">
            Already registered?{" "}
            <Link href={next ? `/login?next=${encodeURIComponent(next)}` : "/login"} className="text-indigo">
              Sign in
            </Link>
          </p>

          {error ? <div className="mt-4"><Notice tone="down">{error}</Notice></div> : null}

          <form action={registerAction} className="mt-5 flex flex-col gap-4">
            {next ? <input type="hidden" name="next" value={next} /> : null}
            <Field label="Full name">
              <Input name="fullName" autoComplete="name" required className="w-full" />
            </Field>
            <Field label="Email">
              <Input name="email" type="email" autoComplete="email" required className="w-full" />
            </Field>
            <Field label="Password" hint="At least 10 characters.">
              <Input
                name="password"
                type="password"
                autoComplete="new-password"
                minLength={10}
                required
                className="w-full"
              />
            </Field>
            <Button type="submit" size="lg" className="w-full">Create account</Button>
          </form>
        </Card>

        <p className="mt-6 text-center text-sm text-ink-muted">
          An account is only needed to book — browsing doctors and hospitals is open to everyone.
        </p>
      </div>
    </main>
  );
}
