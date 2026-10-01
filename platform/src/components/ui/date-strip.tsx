"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { ReactNode } from "react";

/**
 * A horizontal strip of selectable items (dates, times) that scrolls inside
 * its container instead of stretching the page.
 *
 * Why this exists: the booking pages' date rows were plain
 * `flex … overflow-x-auto` divs sitting inside flex/grid children, where the
 * default `min-width: auto` prevents a scroll container from shrinking below
 * its content — so 14 date pills pushed the whole card/page sideways instead
 * of scrolling. This component pins `min-w-0 max-w-full` on the scroller, so
 * it always fits its parent, and adds arrow buttons (with a fade mask) so the
 * off-screen dates are discoverable and reachable without a touchpad gesture.
 *
 * Keyboard/screen-reader note: children are rendered as-is; callers keep
 * their own group semantics (radiogroup / aria-label) via `role` + `ariaLabel`.
 */
export function DateStrip({
  children,
  role,
  ariaLabel,
  className = "",
}: {
  children: ReactNode;
  /** Group semantics for the strip, e.g. "radiogroup" or "group". */
  role?: string;
  ariaLabel: string;
  className?: string;
}) {
  const scrollerRef = useRef<HTMLDivElement>(null);
  const [canLeft, setCanLeft] = useState(false);
  const [canRight, setCanRight] = useState(false);

  const updateArrows = useCallback(() => {
    const el = scrollerRef.current;
    if (!el) return;
    // 1px slack so sub-pixel rounding doesn't render a dead arrow.
    setCanLeft(el.scrollLeft > 1);
    setCanRight(el.scrollLeft < el.scrollWidth - el.clientWidth - 1);
  }, []);

  useEffect(() => {
    updateArrows();
    const el = scrollerRef.current;
    if (!el) return;
    el.addEventListener("scroll", updateArrows, { passive: true });
    // Re-measure when the viewport resizes or the strip's content changes.
    const observer = new ResizeObserver(updateArrows);
    observer.observe(el);
    return () => {
      el.removeEventListener("scroll", updateArrows);
      observer.disconnect();
    };
  }, [updateArrows]);

  const nudge = (dir: -1 | 1) => {
    const el = scrollerRef.current;
    if (!el) return;
    el.scrollBy({ left: dir * Math.max(el.clientWidth * 0.7, 160), behavior: "smooth" });
  };

  return (
    <div className={`relative flex items-center ${className}`}>
      <button
        type="button"
        tabIndex={canLeft ? 0 : -1}
        aria-hidden={!canLeft}
        aria-label="Scroll dates left"
        onClick={() => nudge(-1)}
        className={`absolute left-0 top-1/2 z-10 flex h-7 w-7 -translate-y-1/2 cursor-pointer items-center justify-center rounded-full border border-border bg-card text-ink shadow-sm transition-opacity hover:bg-surface ${
          canLeft ? "opacity-100" : "pointer-events-none opacity-0"
        }`}
      >
        <svg aria-hidden viewBox="0 0 16 16" className="h-3.5 w-3.5" fill="none" stroke="currentColor" strokeWidth="1.8">
          <path d="m10 3-5 5 5 5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>

      <div
        ref={scrollerRef}
        role={role}
        aria-label={ariaLabel}
        // min-w-0 + max-w-full are the actual bug fix: without them a scroll
        // container inside a flex/grid child cannot shrink below its content
        // and stretches the page instead of scrolling.
        className="min-w-0 max-w-full flex gap-2 overflow-x-auto scroll-smooth pb-1 [scrollbar-width:thin]"
      >
        {children}
      </div>

      <button
        type="button"
        tabIndex={canRight ? 0 : -1}
        aria-hidden={!canRight}
        aria-label="Scroll dates right"
        onClick={() => nudge(1)}
        className={`absolute right-0 top-1/2 z-10 flex h-7 w-7 -translate-y-1/2 cursor-pointer items-center justify-center rounded-full border border-border bg-card text-ink shadow-sm transition-opacity hover:bg-surface ${
          canRight ? "opacity-100" : "pointer-events-none opacity-0"
        }`}
      >
        <svg aria-hidden viewBox="0 0 16 16" className="h-3.5 w-3.5" fill="none" stroke="currentColor" strokeWidth="1.8">
          <path d="m6 3 5 5-5 5" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>

      {/* End fade so cut-off items read as "more off-screen", not "broken". */}
      <div
        aria-hidden
        className={`pointer-events-none absolute right-6 top-0 h-full w-6 bg-linear-to-l from-card to-transparent transition-opacity ${
          canRight ? "opacity-100" : "opacity-0"
        }`}
      />
    </div>
  );
}
