import type { InputHTMLAttributes, LabelHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";

export function Field({
  label,
  hint,
  error,
  children,
  ...rest
}: LabelHTMLAttributes<HTMLLabelElement> & {
  label: string;
  hint?: string;
  /** Inline validation message. Rendered with `role="alert"` so screen
   * readers announce it as soon as it appears — never style-only. */
  error?: string;
  children: ReactNode;
}) {
  return (
    <label className="flex flex-col gap-1.5 text-sm" {...rest}>
      <span className="font-medium text-ink">{label}</span>
      {children}
      {error ? (
        <span role="alert" className="text-xs font-medium text-down">
          {error}
        </span>
      ) : hint ? (
        <span className="text-xs text-ink-muted">{hint}</span>
      ) : null}
    </label>
  );
}

export function Input({
  className = "",
  invalid = false,
  ...rest
}: InputHTMLAttributes<HTMLInputElement> & { invalid?: boolean }) {
  return (
    <input
      aria-invalid={invalid || undefined}
      className={`h-10 rounded-control border bg-card px-3 text-sm text-ink placeholder:text-ink-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${
        invalid ? "border-down focus:border-down" : "border-border focus:border-indigo"
      } ${className}`}
      {...rest}
    />
  );
}

export function Textarea({
  className = "",
  rows = 3,
  invalid = false,
  ...rest
}: TextareaHTMLAttributes<HTMLTextAreaElement> & { invalid?: boolean }) {
  return (
    <textarea
      rows={rows}
      aria-invalid={invalid || undefined}
      className={`rounded-control border bg-card px-3 py-2 text-sm text-ink placeholder:text-ink-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus disabled:bg-surface-2 disabled:text-ink-muted ${
        invalid ? "border-down focus:border-down" : "border-border focus:border-indigo"
      } ${className}`}
      {...rest}
    />
  );
}

export function Select({
  className = "",
  invalid = false,
  ...rest
}: SelectHTMLAttributes<HTMLSelectElement> & { invalid?: boolean }) {
  return (
    <select
      aria-invalid={invalid || undefined}
      className={`h-10 rounded-control border bg-card px-3 text-sm text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus ${
        invalid ? "border-down focus:border-down" : "border-border focus:border-indigo"
      } ${className}`}
      {...rest}
    />
  );
}
