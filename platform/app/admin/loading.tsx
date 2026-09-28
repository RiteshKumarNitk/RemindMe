import { Skeleton } from "@/components/ui/index.js";

/**
 * Skeleton for super-admin pages — title plus the row-card list shape that
 * /admin/organizations and /admin/verification render.
 */
export default function AdminLoading() {
  return (
    <div className="flex flex-col gap-7" aria-busy="true" aria-label="Loading">
      <Skeleton className="h-7 w-64" />
      <div className="flex flex-col gap-2.5">
        <Skeleton className="h-16 rounded-2xl" />
        <Skeleton className="h-16 rounded-2xl" />
        <Skeleton className="h-16 rounded-2xl" />
        <Skeleton className="h-16 rounded-2xl" />
      </div>
    </div>
  );
}
