/**
 * Numbered step indicator for the guided organization-setup flow
 * (request §10). Purely presentational and stateless — the flow's real
 * progress lives in the database (the org itself and its completed
 * checklist items), so a half-finished setup is recoverable by design.
 */

import { CheckIcon } from "@/components/ui/check-icon.js";

export interface StepperStep {
  key: string;
  label: string;
  /** Optional destination for completed steps (jump back to review). */
  href?: string;
}

export function Stepper({
  steps,
  current,
  className = "",
}: {
  steps: Array<StepperStep>;
  /** Index of the current step. */
  current: number;
  className?: string;
}) {
  return (
    <nav aria-label="Setup progress" className={className}>
      <ol className="flex flex-wrap items-center gap-x-1 gap-y-2">
        {steps.map((step, i) => {
          const state: "done" | "current" | "upcoming" =
            i < current ? "done" : i === current ? "current" : "upcoming";
          const isLast = i === steps.length - 1;
          const bubble =
            state === "done"
              ? "border-ok bg-ok text-white"
              : state === "current"
                ? "border-indigo bg-indigo text-white"
                : "border-border bg-card text-ink-faint";
          const labelCls =
            state === "current"
              ? "font-semibold text-ink"
              : state === "done"
                ? "text-ink-muted"
                : "text-ink-faint";

          const bubbleEl = (
            <span
              aria-hidden
              className={`flex h-6 w-6 shrink-0 items-center justify-center rounded-full border text-[11px] font-bold ${bubble}`}
            >
              {state === "done" ? <CheckIcon className="h-3.5 w-3.5" /> : i + 1}
            </span>
          );

          return (
            <li key={step.key} className="flex items-center gap-1" aria-current={state === "current" ? "step" : undefined}>
              {step.href && state === "done" ? (
                <a href={step.href} className="flex items-center gap-1.5 no-underline hover:opacity-80">
                  {bubbleEl}
                  <span className={`text-[12.5px] ${labelCls}`}>{step.label}</span>
                </a>
              ) : (
                <span className="flex items-center gap-1.5">
                  {bubbleEl}
                  <span className={`text-[12.5px] ${labelCls}`}>{step.label}</span>
                </span>
              )}
              {!isLast ? <span aria-hidden className="mx-1 h-px w-4 bg-border" /> : null}
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
