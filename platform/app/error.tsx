"use client";

import { useEffect } from "react";
import { Button, ErrorState } from "@/components/ui/index.js";

/**
 * Route-level error boundary. Previously an exception in any server component
 * showed Next's unstyled default error screen — jarring in a healthcare
 * product and off-token. Renders the design system's voice and gives the user
 * a real recovery action. Raw error details are logged to the console only,
 * never shown (they can leak internals).
 */
export default function RootError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    console.error(error);
  }, [error]);

  return (
    <main className="mx-auto max-w-5xl px-5 py-16">
      <ErrorState
        title="Something went wrong"
        description="This page could not be loaded. Your data is safe — try again, or go back and reopen the page."
        action={<Button variant="secondary" onClick={reset}>Try again</Button>}
      />
    </main>
  );
}
