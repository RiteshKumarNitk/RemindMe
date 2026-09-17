import Link from "next/link";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { listOrganizations } from "@/modules/superadmin/service.js";
import { Badge, Button, Card, EmptyState, Field, InitialsAvatar, Input, Select } from "@/components/ui/index.js";

export const dynamic = "force-dynamic";

export default async function AdminOrganizationsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; status?: "all" | "active" | "suspended" }>;
}) {
  const ctx = await requireSuperAdmin();
  const { q, status } = await searchParams;
  const { data: orgs } = await listOrganizations(ctx, { q, status: status ?? "all", limit: 100 });

  return (
    <div className="flex flex-col gap-7">
      <h1 className="font-display text-2xl font-bold text-ink">Clinics ({orgs.length})</h1>

      <form className="flex flex-wrap items-end gap-3">
        <div className="min-w-60 flex-1">
          <Field label="Search by name or slug">
            <Input name="q" defaultValue={q} placeholder="Search…" className="w-full" />
          </Field>
        </div>
        <div className="w-44">
          <Field label="Status">
            <Select name="status" defaultValue={status ?? "all"} className="w-full">
              <option value="all">All</option>
              <option value="active">Active</option>
              <option value="suspended">Suspended</option>
            </Select>
          </Field>
        </div>
        <Button variant="secondary" type="submit">
          Filter
        </Button>
      </form>

      {orgs.length === 0 ? (
        <Card>
          <EmptyState title="No clinics found." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {orgs.map((o) => (
            <Link
              key={o.id}
              href={`/admin/organizations/${o.id}`}
              className="flex flex-wrap items-center gap-3 rounded-2xl border border-border bg-card px-4 py-3 no-underline transition-colors hover:border-indigo"
            >
              <InitialsAvatar name={o.name} />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-ink">{o.name}</div>
                <div className="truncate text-[11.5px] text-ink-muted">{o.slug}</div>
              </div>
              <Badge tone={o.isActive ? "ok" : "coral"}>{o.isActive ? "Active" : "Suspended"}</Badge>
              <div className="flex gap-3 text-[11.5px] tabular-nums text-ink-faint">
                <span>{o._count.memberships} members</span>
                <span>{o._count.patients} patients</span>
                <span>{o._count.appointments} appts</span>
              </div>
              <span className="w-20 shrink-0 text-right text-[11px] text-ink-faint">
                {new Date(o.createdAt).toLocaleDateString()}
              </span>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
