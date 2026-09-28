import { Card, Skeleton } from "@/components/ui/index.js";

/**
 * Instant skeleton for every org-dashboard navigation. Previously the
 * `force-dynamic` pages rendered nothing until the DB round-trips finished,
 * so slower clinic connections stared at a blank content area. This mirrors
 * the common page shape (title, hero/cards, stat tiles, list) loosely —
 * close enough to stop layout jump, obviously a placeholder, never fakes
 * content.
 */
export default function DashboardLoading() {
  return (
    <div className="flex flex-col gap-7" aria-busy="true" aria-label="Loading">
      <Skeleton className="h-7 w-56" />
      <div className="grid gap-5 lg:grid-cols-[1.4fr_1fr]">
        <Skeleton className="min-h-50 rounded-3xl" />
        <div className="flex flex-col gap-4">
          <Skeleton className="min-h-20 rounded-2xl" />
          <Skeleton className="min-h-20 rounded-2xl" />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <Skeleton className="h-28 rounded-card" />
        <Skeleton className="h-28 rounded-card" />
        <Skeleton className="h-28 rounded-card" />
        <Skeleton className="h-28 rounded-card" />
      </div>
      <Card className="flex flex-col gap-3">
        <Skeleton className="h-4 w-40" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
        <Skeleton className="h-12 w-full" />
      </Card>
    </div>
  );
}
