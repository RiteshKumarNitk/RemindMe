import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { listStaff } from "@/modules/staff/service.js";
import { db } from "@/lib/db.js";
import { Button, Card, EmptyState, ErrorNote, Field, SectionTitle, Table, td, th } from "../../ui.js";
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
    <div>
      <SectionTitle>Staff</SectionTitle>
      <Card style={{ marginBottom: 20 }}>
        {staff.length === 0 ? (
          <EmptyState>No staff members yet.</EmptyState>
        ) : (
          <Table>
            <thead>
              <tr>
                <th style={th}>Name</th>
                <th style={th}>Title</th>
                <th style={th}>Status</th>
              </tr>
            </thead>
            <tbody>
              {staff.map((s) => (
                <tr key={s.id}>
                  <td style={td}>{nameOf(s.userId)}</td>
                  <td style={td}>{s.jobTitle ?? "—"}</td>
                  <td style={td}>{s.isActive ? "Active" : "Inactive"}</td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>

      <Card style={{ maxWidth: 420 }}>
        <SectionTitle>Add staff</SectionTitle>
        <ErrorNote message={error} />
        <form action={createStaffAction.bind(null, orgId)}>
          <Field label="Full name" name="fullName" required />
          <Field label="Email" name="email" type="email" required />
          <Field label="Job title" name="jobTitle" placeholder="Front Desk" />
          <div style={{ marginTop: 8 }}>
            <Button>Add staff</Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
