import type { ReactNode } from "react";

export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-card border border-dashed border-border px-6 py-12 text-center">
      <p className="text-sm font-medium text-ink">{title}</p>
      {description ? <p className="max-w-sm text-sm text-ink-muted">{description}</p> : null}
      {action}
    </div>
  );
}

export function ErrorState({
  title = "Something went wrong",
  description,
  action,
}: {
  title?: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-card border border-down/30 bg-down/5 px-6 py-12 text-center">
      <p className="text-sm font-medium text-down">{title}</p>
      {description ? <p className="max-w-sm text-sm text-ink-muted">{description}</p> : null}
      {action}
    </div>
  );
}

export function Skeleton({ className = "" }: { className?: string }) {
  return <div className={`animate-pulse rounded-control bg-border ${className}`} />;
}

const NOTICE_TONE = {
  ok: "border-ok/20 bg-ok/10 text-ok",
  down: "border-down/20 bg-down/10 text-down",
} as const;

/** A small inline banner for a one-line success/error message under a page
 * heading or form — lighter-weight than `ErrorState`, which is for an empty
 * section, not a form-submission result. */
export function Notice({ tone, children }: { tone: keyof typeof NOTICE_TONE; children: ReactNode }) {
  return <div className={`rounded-2xl border px-4 py-3 text-sm ${NOTICE_TONE[tone]}`}>{children}</div>;
}
