import { Card, Skeleton } from "@/components/ui/index.js";

/**
 * Skeleton for the public discovery section (hospitals; doctors uses the same
 * shape via its own loading file). Mirrors the page header + card-grid so the
 * grid does not collapse while the public listing loads.
 */
export default function HospitalsLoading() {
  return (
    <div className="mx-auto max-w-5xl px-5 py-10" aria-busy="true" aria-label="Loading">
      <Skeleton className="h-7 w-72" />
      <Skeleton className="mt-4 h-12 w-full max-w-md rounded-full" />
      <div className="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2 md:grid-cols-3">
        <Card className="h-32" aria-hidden />
        <Card className="h-32" aria-hidden />
        <Card className="h-32" aria-hidden />
        <Card className="h-32" aria-hidden />
        <Card className="h-32" aria-hidden />
        <Card className="h-32" aria-hidden />
      </div>
    </div>
  );
}
