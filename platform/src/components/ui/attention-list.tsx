import Link from "next/link";
import type { ReactNode } from "react";
import { AlertIcon, ArrowIcon } from "@/components/ui/attention-icons.js";

/**
 * The "needs attention" band every role dashboard opens with (request §29:
 * current state → important attention → primary actions). Rendered as a
 * compact list of one-line items, each optionally linking to the page that
 * fixes it. Collapses away entirely when there is nothing to say — an empty
 * attention list must never look like missing content.
 */

export interface AttentionItem {
  key: string;
  /** Severity: danger first, then warn, then info. */
  severity: "danger" | "warn" | "info";
  title: string;
  /** Where to fix it, if a destination exists. */
  href?: string;
  actionLabel?: string;
  icon?: ReactNode;
}

const SEVERITY_STYLE = {
  danger: { row: "border-down/25 bg-down/5", dot: "bg-down", text: "text-down" },
  warn: { row: "border-warn/25 bg-warn/5", dot: "bg-warn", text: "text-warn" },
  info: { row: "border-indigo/20 bg-indigo/5", dot: "bg-indigo", text: "text-indigo" },
} as const;

const SEVERITY_ORDER = { danger: 0, warn: 1, info: 2 } as const;

export function AttentionList({
  title = "Attention required",
  items,
  className = "",
}: {
  title?: string;
  items: Array<AttentionItem>;
  className?: string;
}) {
  if (items.length === 0) return null;

  const sorted = [...items].sort((a, b) => SEVERITY_ORDER[a.severity] - SEVERITY_ORDER[b.severity]);

  return (
    <section aria-label={title} className={className}>
      <h2 className="mb-2 flex items-center gap-1.5 text-[13px] font-semibold text-ink">
        <AlertIcon className="h-3.75 w-3.75 text-warn" />
        {title}
        <span className="font-normal text-ink-faint">({items.length})</span>
      </h2>
      <ul className="flex flex-col gap-2">
        {sorted.map((item) => {
          const s = SEVERITY_STYLE[item.severity];
          const body = (
            <>
              <span aria-hidden className={`mt-1.5 inline-block h-2 w-2 shrink-0 rounded-full ${s.dot}`} />
              <span className="min-w-0 flex-1 text-[13px] font-medium text-ink">{item.title}</span>
              {item.href && item.actionLabel ? (
                <span className={`inline-flex shrink-0 items-center gap-1 text-[12.5px] font-semibold ${s.text}`}>
                  {item.actionLabel}
                  <ArrowIcon className="h-3 w-3" />
                </span>
              ) : null}
            </>
          );
          return (
            <li key={item.key}>
              {item.href ? (
                <Link
                  href={item.href}
                  className={`flex items-start gap-2.5 rounded-control border px-3.5 py-2.5 no-underline transition-colors hover:bg-surface-2 ${s.row}`}
                >
                  {body}
                </Link>
              ) : (
                <div className={`flex items-start gap-2.5 rounded-control border px-3.5 py-2.5 ${s.row}`}>
                  {body}
                </div>
              )}
            </li>
          );
        })}
      </ul>
    </section>
  );
}
