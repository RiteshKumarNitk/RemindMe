import Link from "next/link";
import type { Completeness, CompletenessItem } from "@/modules/clinics/completeness.js";

/**
 * Profile-completeness meter (request §14). The bar is driven entirely by
 * `computeProfileCompleteness` — the same pure module the onboarding
 * checklist and admin surfaces use — so every surface shows the identical
 * percentage, computed from real fields, never an arbitrary number.
 *
 * Visual convention (light theme, same family as StatTile/Badge):
 *   ≥80%  ok tint   — publish-and-verify territory
 *   40–79 warn tint — getting there
 *   <40%  down tint — bare-bones profile
 */

function tone(percent: number): { bar: string; text: string } {
  if (percent >= 80) return { bar: "bg-ok", text: "text-ok" };
  if (percent >= 40) return { bar: "bg-warn", text: "text-warn" };
  return { bar: "bg-down", text: "text-down" };
}

export function CompletionMeter({
  completeness,
  compact = false,
  className = "",
}: {
  completeness: Completeness;
  compact?: boolean;
  className?: string;
}) {
  const t = tone(completeness.percent);

  return (
    <div
      className={className}
      role="progressbar"
      aria-valuenow={completeness.percent}
      aria-valuemin={0}
      aria-valuemax={100}
      aria-label={`Profile ${completeness.percent}% complete`}
    >
      <div className="flex items-baseline justify-between gap-3">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">
          Profile completeness
        </span>
        <span className={`font-display text-lg font-bold tabular-nums ${t.text}`}>
          {completeness.percent}%
        </span>
      </div>
      <div
        className={`mt-1.5 w-full overflow-hidden rounded-full bg-surface-2 ${compact ? "h-1.5" : "h-2.5"}`}
      >
        <div
          className={`h-full rounded-full transition-[width] ${t.bar}`}
          style={{ width: `${Math.max(completeness.percent, 2)}%` }}
        />
      </div>

      {!compact && completeness.missing.length > 0 ? (
        <ul className="mt-3 flex flex-col gap-1">
          {completeness.missing.slice(0, 4).map((item: CompletenessItem) => (
            <li key={item.key}>
              <Link
                href={item.href}
                className="flex items-center gap-2 text-[13px] text-ink-muted no-underline hover:text-indigo"
              >
                <span aria-hidden className="inline-block h-1.5 w-1.5 shrink-0 rounded-full bg-warn" />
                <span className="underline decoration-border underline-offset-2">{item.label}</span>
                <span aria-hidden className="text-ink-faint">→</span>
              </Link>
            </li>
          ))}
          {completeness.missing.length > 4 ? (
            <li className="pl-3.5 text-[12px] text-ink-faint">
              +{completeness.missing.length - 4} more to complete
            </li>
          ) : null}
        </ul>
      ) : null}

      {!compact && completeness.missing.length === 0 ? (
        <p className="mt-2 text-[13px] font-medium text-ok">
          Everything&rsquo;s filled in — this profile is complete.
        </p>
      ) : null}
    </div>
  );
}
