import type { ReactNode } from "react";
import { Card } from "./card.js";

type Tone = "indigo" | "ok" | "coral" | "warn" | "danger" | "neutral";

const TONE_CLASSES: Record<Tone, string> = {
  indigo: "bg-indigo/10 text-indigo-dark",
  ok: "bg-ok/10 text-ok",
  coral: "bg-coral/10 text-coral",
  warn: "bg-warn/10 text-warn",
  danger: "bg-down/10 text-down",
  neutral: "bg-surface-2 text-ink-muted",
};

const TREND_CLASSES = { up: "text-ok", down: "text-down", flat: "text-ink-faint" } as const;

/** One tile in a dashboard's stat grid: a tinted icon, the number, and a
 * one-line trend/context note underneath. */
export function StatTile({
  icon,
  tone = "indigo",
  label,
  value,
  trend,
  trendDirection = "flat",
}: {
  icon: ReactNode;
  tone?: Tone;
  label: string;
  value: ReactNode;
  trend?: ReactNode;
  trendDirection?: "up" | "down" | "flat";
}) {
  return (
    <Card className="flex flex-col gap-2.5">
      <div className="flex items-center justify-between">
        <span className="text-[11px] font-semibold uppercase tracking-wide text-ink-faint">{label}</span>
        <span className={`flex h-7.5 w-7.5 items-center justify-center rounded-lg [&_svg]:h-3.75 [&_svg]:w-3.75 ${TONE_CLASSES[tone]}`}>
          {icon}
        </span>
      </div>
      <div className="font-display text-2xl font-bold tabular-nums text-ink">{value}</div>
      {trend ? <div className={`text-[11.5px] font-semibold ${TREND_CLASSES[trendDirection]}`}>{trend}</div> : null}
    </Card>
  );
}
