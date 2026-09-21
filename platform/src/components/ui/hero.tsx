import type { HTMLAttributes, ReactNode } from "react";

/** The two-column hero grid used at the top of every role's dashboard. */
export function Hero({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={`grid gap-5 lg:grid-cols-[1.4fr_1fr] ${className}`} {...rest} />;
}

/** The gradient "what matters right now" card — next appointment, who's in
 * consultation, etc. Deliberately the one place on the dashboard with strong
 * color, so it reads as the answer to "what should I do next." */
export function HeroMain({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`relative flex min-h-50 flex-col justify-between gap-5 overflow-hidden rounded-3xl bg-linear-to-br from-indigo to-indigo-dark p-7 text-white before:absolute before:inset-0 before:bg-[radial-gradient(circle_at_88%_-10%,rgba(255,255,255,0.22),transparent_55%)] ${className}`}
      {...rest}
    />
  );
}

export function HeroSide({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={`flex flex-col gap-4 ${className}`} {...rest} />;
}

export function HeroLabel({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={`text-[11px] font-semibold uppercase tracking-wide text-white/75 ${className}`} {...rest} />;
}

export function HeroActions({ className = "", ...rest }: HTMLAttributes<HTMLDivElement>) {
  return <div className={`relative flex flex-wrap gap-2 ${className}`} {...rest} />;
}

/** A big-number card in the hero's side column — a live queue token, a
 * doctor's average consult time. `value` is optional so a card can be
 * label + sub only (e.g. "Today's pace"). */
export function SideStat({ value, label, sub }: { value?: ReactNode; label: string; sub?: ReactNode }) {
  return (
    <div className="flex flex-1 items-center gap-4 rounded-2xl border border-border bg-card p-5">
      {value != null ? <div className="font-display text-3xl font-bold tabular-nums text-indigo">{value}</div> : null}
      <div className="min-w-0">
        <div className="mb-1 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">{label}</div>
        {sub ? <div className="text-[11.5px] text-ink-muted">{sub}</div> : null}
      </div>
    </div>
  );
}
