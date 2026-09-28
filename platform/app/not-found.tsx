import Link from "next/link";

/**
 * App-wide 404. Replaces Next's plain default so a mistyped URL still feels
 * like the product and offers the two places users almost certainly want.
 */
export default function NotFound() {
  return (
    <main className="flex min-h-[60vh] flex-col items-center justify-center gap-3 px-6 py-16 text-center">
      <h1 className="text-lg font-semibold text-ink">Page not found</h1>
      <p className="max-w-sm text-sm text-ink-muted">
        The page you are looking for does not exist or may have moved.
      </p>
      <div className="mt-2 flex gap-3">
        <Link
          href="/"
          className="rounded-control bg-indigo px-4 py-2 text-sm font-medium text-white no-underline hover:bg-indigo-dark"
        >
          Go to the homepage
        </Link>
        <Link
          href="/doctors"
          className="rounded-control border border-border bg-card px-4 py-2 text-sm font-medium text-ink no-underline hover:bg-surface"
        >
          Find a doctor
        </Link>
      </div>
    </main>
  );
}
