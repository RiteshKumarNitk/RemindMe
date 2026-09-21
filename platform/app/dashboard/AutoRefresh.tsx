"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";

/** Re-runs the current route's server components every `seconds` (queue board). */
export function AutoRefresh({ seconds = 10 }: { seconds?: number }) {
  const router = useRouter();
  useEffect(() => {
    const id = setInterval(() => router.refresh(), seconds * 1000);
    return () => clearInterval(id);
  }, [router, seconds]);
  return null;
}
