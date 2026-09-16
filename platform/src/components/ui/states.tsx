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
