import type { SVGProps } from "react";

/** Same 1.8-stroke check as dashboard-icons.tsx, importable from the ui kit
 * (Stepper's completed step) without pulling in the shell icon module. */
export function CheckIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2.2} strokeLinecap="round" strokeLinejoin="round" {...props}>
      <path d="M20 6 9 17l-5-5" />
    </svg>
  );
}
