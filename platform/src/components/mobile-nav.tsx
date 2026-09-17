"use client";

import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import { usePathname } from "next/navigation";
import { CloseIcon, MenuIcon } from "./dashboard-icons.js";

const MobileNavContext = createContext<{ open: boolean; setOpen: (v: boolean) => void } | null>(null);

/**
 * Owns the mobile sidebar-drawer open/closed state so a server-rendered
 * layout (sidebar content, topbar) can still be built entirely server-side —
 * only the toggle button, backdrop, and slide-transform need client state.
 */
export function MobileNavProvider({ children }: { children: ReactNode }) {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();
  // The layout doesn't remount between sibling pages, so close the drawer
  // whenever the route actually changes — otherwise it stays open over the
  // new page after a nav-link tap.
  useEffect(() => {
    setOpen(false);
  }, [pathname]);
  return <MobileNavContext.Provider value={{ open, setOpen }}>{children}</MobileNavContext.Provider>;
}

function useMobileNav() {
  const ctx = useContext(MobileNavContext);
  if (!ctx) throw new Error("useMobileNav must be used inside MobileNavProvider");
  return ctx;
}

export function MobileNavButton() {
  const { open, setOpen } = useMobileNav();
  return (
    <button
      type="button"
      onClick={() => setOpen(!open)}
      aria-label={open ? "Close navigation" : "Open navigation"}
      aria-expanded={open}
      className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl border border-border bg-card text-ink-muted hover:bg-surface-2 hover:text-ink md:hidden"
    >
      {open ? <CloseIcon className="h-4.5 w-4.5" /> : <MenuIcon className="h-4.5 w-4.5" />}
    </button>
  );
}

export function MobileNavAside({ children }: { children: ReactNode }) {
  const { open, setOpen } = useMobileNav();
  return (
    <>
      {open ? (
        <div
          className="fixed inset-0 z-30 bg-ink/40 md:hidden"
          onClick={() => setOpen(false)}
          aria-hidden="true"
        />
      ) : null}
      <aside
        className={`fixed inset-y-0 left-0 z-40 flex w-60 shrink-0 -translate-x-full flex-col gap-1 border-r border-border bg-card p-3 transition-transform duration-200 md:static md:translate-x-0 ${open ? "translate-x-0" : ""}`}
      >
        {children}
      </aside>
    </>
  );
}
