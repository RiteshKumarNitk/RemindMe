import type { InputHTMLAttributes, LabelHTMLAttributes, ReactNode, SelectHTMLAttributes } from "react";

export function Field({
  label,
  hint,
  children,
  ...rest
}: LabelHTMLAttributes<HTMLLabelElement> & { label: string; hint?: string; children: ReactNode }) {
  return (
    <label className="flex flex-col gap-1.5 text-sm" {...rest}>
      <span className="font-medium text-ink">{label}</span>
      {children}
      {hint ? <span className="text-xs text-ink-muted">{hint}</span> : null}
    </label>
  );
}

export function Input({ className = "", ...rest }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={`h-10 rounded-control border border-border bg-card px-3 text-sm text-ink placeholder:text-ink-muted focus:border-indigo focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${className}`}
      {...rest}
    />
  );
}

export function Select({ className = "", ...rest }: SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={`h-10 rounded-control border border-border bg-card px-3 text-sm text-ink focus:border-indigo focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${className}`}
      {...rest}
    />
  );
}
