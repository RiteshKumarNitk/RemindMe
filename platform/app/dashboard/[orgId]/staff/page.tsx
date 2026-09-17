import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { listStaff } from "@/modules/staff/service.js";
import { db } from "@/lib/db.js";
import { Badge, Button, Card, CardSubtitle, EmptyState, Field, InitialsAvatar, Input, Notice } from "@/components/ui/index.js";
import { createStaffAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function StaffPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);
  const { error } = await searchParams;

  const staff = await listStaff(ctx);
  const users = await db.user.findMany({
    where: { id: { in: staff.map((s) => s.userId) } },
    select: { id: true, fullName: true, email: true },
  });
  const nameOf = (userId: string) => users.find((u) => u.id === userId)?.fullName ?? "—";

  return (
    <div className="flex flex-col gap-7">
      <h1 className="font-display text-2xl font-bold text-ink">Staff</h1>

      {staff.length === 0 ? (
        <Card>
          <EmptyState title="No staff members yet." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {staff.map((s) => (
            <Card key={s.id} className="flex items-center gap-3 p-4!">
              <InitialsAvatar name={nameOf(s.userId)} />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-ink">{nameOf(s.userId)}</div>
                <div className="truncate text-[11.5px] text-ink-muted">{s.jobTitle ?? "No title set"}</div>
              </div>
              <Badge tone={s.isActive ? "ok" : "neutral"}>{s.isActive ? "Active" : "Inactive"}</Badge>
            </Card>
          ))}
        </div>
      )}

      <Card>
        <CardSubtitle>Add staff</CardSubtitle>
        {error ? (
          <div className="mt-3">
            <Notice tone="down">{error}</Notice>
          </div>
        ) : null}
        <form action={createStaffAction.bind(null, orgId)} className="mt-4 flex max-w-md flex-col gap-4">
          <Field label="Full name">
            <Input name="fullName" required className="w-full" />
          </Field>
          <Field label="Email">
            <Input name="email" type="email" required className="w-full" />
          </Field>
          <Field label="Job title">
            <Input name="jobTitle" placeholder="Front Desk" className="w-full" />
          </Field>
          <Button className="self-start">Add staff</Button>
        </form>
      </Card>
    </div>
  );
}
