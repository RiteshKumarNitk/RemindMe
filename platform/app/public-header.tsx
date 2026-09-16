import Link from "next/link";

export function PublicHeader() {
  return (
    <header className="border-b border-border bg-card">
      <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-5">
        <Link href="/" className="flex items-center gap-2 no-underline">
          <span
            className="inline-block h-7 w-7 rounded-lg"
            style={{ background: "linear-gradient(135deg, var(--indigo), var(--coral))" }}
            aria-hidden
          />
          <strong className="text-sm text-ink">DoseWise</strong>
        </Link>
        <nav className="flex items-center gap-5 text-sm">
          <Link href="/doctors" className="text-ink no-underline hover:text-indigo">
            Find a doctor
          </Link>
          <Link href="/hospitals" className="text-ink no-underline hover:text-indigo">
            Find a hospital
          </Link>
          <Link href="/login" className="text-ink no-underline hover:text-indigo">
            Log in
          </Link>
          <Link
            href="/register"
            className="rounded-full bg-indigo px-4 py-1.5 text-white no-underline hover:bg-indigo-dark"
          >
            Sign up
          </Link>
        </nav>
      </div>
    </header>
  );
}
