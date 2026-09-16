import type { HTMLAttributes } from "react";

type BadgeTone = "neutral" | "ok" | "down" | "indigo";

const TONE_CLASSES: Record<BadgeTone, string> = {
  neutral: "bg-surface text-ink-muted border-border",
  ok: "bg-ok/10 text-ok border-ok/20",
  down: "bg-down/10 text-down border-down/20",
  indigo: "bg-indigo/10 text-indigo border-indigo/20",
};

export interface BadgeProps extends HTMLAttributes<HTMLSpanElement> {
  tone?: BadgeTone;
}

export function Badge({ tone = "neutral", className = "", ...rest }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center gap-1 rounded-full border px-2.5 py-0.5 text-xs font-medium ${TONE_CLASSES[tone]} ${className}`}
      {...rest}
    />
  );
}
