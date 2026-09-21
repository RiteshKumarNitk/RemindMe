import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { listMembers } from "@/modules/clinics/service.js";
import { Badge, Button, Card, CardSubtitle, Field, InitialsAvatar, Input, Notice, Select } from "@/components/ui/index.js";
import { inviteMemberAction, removeMemberAction, saveMemberAction } from "./actions.js";

export const dynamic = "force-dynamic";

const CAPS = [
  { key: "CLINICAL_RECORD_READ", label: "View clinical records" },
  { key: "CLINICAL_RECORD_WRITE", label: "Edit clinical records" },
  { key: "BILLING_MANAGE", label: "Billing" },
  { key: "DATA_EXPORT", label: "Data export" },
] as const;

const ROLE_BADGE: Record<string, "coral" | "indigo" | "ok" | "warn"> = {
  CLINIC_ADMIN: "coral",
  DOCTOR: "indigo",
  RECEPTIONIST: "ok",
  PATIENT: "warn",
};

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
    <div className="flex flex-col gap-7">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Team</h1>
        <p className="mt-1 text-sm text-ink-muted">
          Clinical-record capabilities can&rsquo;t be granted to your own account — ask a different clinic admin.
        </p>
      </div>

      {error ? <Notice tone="down">{error}</Notice> : null}

      <div className="flex flex-col gap-3">
        {members.map((m) => (
          <Card key={m.id}>
            <div className="flex flex-wrap items-center gap-3">
              <InitialsAvatar name={m.user.fullName} />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-ink">{m.user.fullName}</div>
                <div className="truncate text-[11.5px] text-ink-muted">{m.user.email}</div>
              </div>
              <Badge tone={ROLE_BADGE[m.role] ?? "neutral"}>{m.role}</Badge>
              <Badge tone={m.status === "ACTIVE" ? "ok" : "neutral"}>{m.status}</Badge>
              <form action={removeMemberAction.bind(null, orgId, m.id)}>
                <Button variant="danger" size="sm" type="submit">
                  Remove
                </Button>
              </form>
            </div>

            <form action={saveMemberAction.bind(null, orgId, m.id)} className="mt-4 flex flex-col gap-4 border-t border-border pt-4">
              <div className="grid grid-cols-2 gap-3 sm:max-w-md">
                <Field label="Role">
                  <Select name="role" defaultValue={m.role} className="w-full">
                    <option value="PATIENT">PATIENT</option>
                    <option value="DOCTOR">DOCTOR</option>
                    <option value="RECEPTIONIST">RECEPTIONIST</option>
                    <option value="CLINIC_ADMIN">CLINIC_ADMIN</option>
                  </Select>
                </Field>
                <Field label="Status">
                  <Select name="status" defaultValue={m.status} className="w-full">
                    <option value="ACTIVE">ACTIVE</option>
                    <option value="SUSPENDED">SUSPENDED</option>
                  </Select>
                </Field>
              </div>
              <div>
                <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Capabilities</div>
                <div className="flex flex-wrap gap-x-5 gap-y-2">
                  {CAPS.map((c) => (
                    <label key={c.key} className="flex items-center gap-2 text-[13px] text-ink">
                      <input
                        type="checkbox"
                        name={`cap-${c.key}`}
                        defaultChecked={m.capabilities.includes(c.key)}
                        className="h-4 w-4 accent-indigo"
                      />
                      {c.label}
                    </label>
                  ))}
                </div>
              </div>
              <Button variant="ghost" size="sm" className="self-start">
                Save
              </Button>
            </form>
          </Card>
        ))}
      </div>

      <Card className="max-w-md">
        <CardSubtitle>Invite a member</CardSubtitle>
        <form action={inviteMemberAction.bind(null, orgId)} className="mt-4 flex flex-col gap-4">
          <Field label="Full name">
            <Input name="fullName" required className="w-full" />
          </Field>
          <Field label="Email">
            <Input name="email" type="email" required className="w-full" />
          </Field>
          <Field label="Role">
            <Select name="role" defaultValue="RECEPTIONIST" className="w-full">
              <option value="RECEPTIONIST">RECEPTIONIST</option>
              <option value="DOCTOR">DOCTOR</option>
              <option value="CLINIC_ADMIN">CLINIC_ADMIN</option>
              <option value="PATIENT">PATIENT</option>
            </Select>
          </Field>
          <Button className="self-start">Invite</Button>
        </form>
      </Card>
    </div>
  );
}
