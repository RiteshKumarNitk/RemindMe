import type { InputHTMLAttributes } from "react";

/**
 * Rounded search input used by public discovery and staff search. `name` is
 * also the fallback accessible name — placeholder-only inputs were previously
 * announced with no purpose by screen readers, and placeholders disappear on
 * input in every browser.
 */
export function SearchBar({
  name = "search",
  className = "",
  ...rest
}: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <div className={`flex items-center gap-2 rounded-full border border-border bg-card px-4 shadow-sm ${className}`}>
      <svg
        aria-hidden="true"
        viewBox="0 0 20 20"
        className="h-4 w-4 shrink-0 text-ink-muted"
        fill="none"
        stroke="currentColor"
        strokeWidth="1.6"
      >
        <circle cx="9" cy="9" r="6" />
        <path d="m17 17-3.5-3.5" strokeLinecap="round" />
      </svg>
      <input
        type="search"
        aria-label="Search"
        className="h-12 w-full bg-transparent text-sm text-ink placeholder:text-ink-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
        {...rest}
      />
    </div>
  );
}
