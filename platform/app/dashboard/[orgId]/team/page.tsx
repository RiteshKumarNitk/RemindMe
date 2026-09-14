import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { listMembers } from "@/modules/clinics/service.js";
import { Button, Card, ErrorNote, Field, Select, SectionTitle, table, td, th } from "../../ui.js";
import { inviteMemberAction, removeMemberAction, saveMemberAction } from "./actions.js";

export const dynamic = "force-dynamic";

const CAPS = [
  { key: "CLINICAL_RECORD_READ", label: "View clinical records" },
  { key: "CLINICAL_RECORD_WRITE", label: "Edit clinical records" },
  { key: "BILLING_MANAGE", label: "Billing" },
  { key: "DATA_EXPORT", label: "Data export" },
] as const;

export default async function TeamPage({
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
  const members = await listMembers(ctx);

  return (
    <div>
      <SectionTitle>Team</SectionTitle>
      <ErrorNote message={error} />
      <p style={{ fontSize: 13, color: "var(--ink-muted)", marginTop: -8, marginBottom: 16 }}>
        Clinical-record capabilities can&rsquo;t be granted to your own account — ask a
        different clinic admin.
      </p>

      <div style={{ display: "grid", gap: 12, marginBottom: 24 }}>
        {members.map((m) => (
          <Card key={m.id}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 10 }}>
              <div>
                <div style={{ fontWeight: 700 }}>{m.user.fullName}</div>
                <div style={{ fontSize: 12, color: "var(--ink-muted)" }}>{m.user.email}</div>
              </div>
              <form action={removeMemberAction.bind(null, orgId, m.id)}>
                <Button variant="danger" type="submit">
                  Remove
                </Button>
              </form>
            </div>
            <form action={saveMemberAction.bind(null, orgId, m.id)}>
              <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
                <div style={{ minWidth: 160 }}>
                  <Select label="Role" name="role" defaultValue={m.role}>
                    <option value="PATIENT">PATIENT</option>
                    <option value="DOCTOR">DOCTOR</option>
                    <option value="RECEPTIONIST">RECEPTIONIST</option>
                    <option value="CLINIC_ADMIN">CLINIC_ADMIN</option>
                  </Select>
                </div>
                <div style={{ minWidth: 160 }}>
                  <Select label="Status" name="status" defaultValue={m.status}>
                    <option value="ACTIVE">ACTIVE</option>
                    <option value="SUSPENDED">SUSPENDED</option>
                  </Select>
                </div>
              </div>
              <div style={{ display: "flex", gap: 16, flexWrap: "wrap", margin: "6px 0 12px" }}>
                {CAPS.map((c) => (
                  <label key={c.key} style={{ fontSize: 13, display: "flex", alignItems: "center", gap: 6 }}>
                    <input
                      type="checkbox"
                      name={`cap-${c.key}`}
                      defaultChecked={m.capabilities.includes(c.key)}
                    />
                    {c.label}
                  </label>
                ))}
              </div>
              <Button variant="ghost">Save</Button>
            </form>
          </Card>
        ))}
      </div>

      <Card style={{ maxWidth: 420 }}>
        <SectionTitle>Invite a member</SectionTitle>
        <form action={inviteMemberAction.bind(null, orgId)}>
          <Field label="Full name" name="fullName" required />
          <Field label="Email" name="email" type="email" required />
          <Select label="Role" name="role" defaultValue="RECEPTIONIST">
            <option value="RECEPTIONIST">RECEPTIONIST</option>
            <option value="DOCTOR">DOCTOR</option>
            <option value="CLINIC_ADMIN">CLINIC_ADMIN</option>
            <option value="PATIENT">PATIENT</option>
          </Select>
          <div style={{ marginTop: 8 }}>
            <Button>Invite</Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
