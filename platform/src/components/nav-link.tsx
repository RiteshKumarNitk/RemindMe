"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import type { CSSProperties, ReactNode } from "react";

/**
 * A sidebar nav link that sets `aria-current="page"` when it matches the current
 * route, so keyboard/screen-reader users (and `.dashboard-nav`'s active-state CSS
 * in globals.css) get a real signal for which page is open — plain `Link`s gave
 * none. `exact` is for entries like "Overview" whose href is the org root and
 * would otherwise match every nested route too.
 */
export function NavLink({
  href,
  exact = false,
  style,
  children,
}: {
  href: string;
  exact?: boolean;
  style?: CSSProperties;
  children: ReactNode;
}) {
  const pathname = usePathname();
  const isActive = exact ? pathname === href : pathname === href || pathname.startsWith(`${href}/`);

  return (
    <Link href={href} aria-current={isActive ? "page" : undefined} style={style}>
      {children}
    </Link>
  );
}
