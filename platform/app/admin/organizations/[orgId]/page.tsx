import type { ReactNode } from "react";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { getOrganizationDetail } from "@/modules/superadmin/service.js";
import { Badge, Button, Card, InitialsAvatar, Notice } from "@/components/ui/index.js";
import { setOrganizationActiveAction, setOrganizationVerificationAction } from "./actions.js";

const VERIFICATION_TONE: Record<string, "ok" | "coral" | "indigo" | "neutral"> = {
  DRAFT: "neutral",
  PENDING_VERIFICATION: "coral",
  VERIFIED: "ok",
  REJECTED: "coral",
};

export const dynamic = "force-dynamic";

export default async function AdminOrganizationDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const ctx = await requireSuperAdmin();
  const { orgId } = await params;
  const { error } = await searchParams;

  const { org, memberships } = await getOrganizationDetail(ctx, orgId);

  return (
    <div className="flex flex-col gap-7">
      <div className="flex items-center gap-3">
        <InitialsAvatar name={org.name} />
        <h1 className="font-display text-2xl font-bold text-ink">{org.name}</h1>
      </div>
      {error ? <Notice tone="down">{error}</Notice> : null}

      <Card className="max-w-xl">
        <div className="flex flex-col">
          <Row label="Slug" value={org.slug} />
          <Row label="Timezone" value={org.timezone} />
          <Row label="Status" value={<Badge tone={org.isActive ? "ok" : "coral"}>{org.isActive ? "Active" : "Suspended"}</Badge>} />
          <Row
            label="Verification"
            value={<Badge tone={VERIFICATION_TONE[org.verificationStatus] ?? "neutral"}>{org.verificationStatus}</Badge>}
          />
          <Row label="Publicly listed" value={org.isPubliclyListed ? "Yes" : "No"} />
          <Row label="Created" value={new Date(org.createdAt).toLocaleString()} />
          <Row label="Members" value={String(org._count.memberships)} />
          <Row label="Doctors" value={String(org._count.doctorProfiles)} />
          <Row label="Staff" value={String(org._count.staffProfiles)} />
          <Row label="Patients" value={String(org._count.patients)} />
          <Row label="Appointments" value={String(org._count.appointments)} last />
        </div>

        <div className="mt-4 flex flex-wrap gap-2">
          <form action={setOrganizationActiveAction.bind(null, orgId, !org.isActive)}>
            <Button variant={org.isActive ? "danger" : "primary"}>
              {org.isActive ? "Suspend this clinic" : "Reactivate this clinic"}
            </Button>
          </form>
          {org.verificationStatus === "PENDING_VERIFICATION" ? (
            <>
              <form action={setOrganizationVerificationAction.bind(null, orgId, "VERIFIED")}>
                <Button>Approve verification</Button>
              </form>
              <form action={setOrganizationVerificationAction.bind(null, orgId, "REJECTED")}>
                <Button variant="danger">Reject</Button>
              </form>
            </>
          ) : null}
        </div>
      </Card>

      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">Members</h2>
        <Card>
          <div className="flex flex-col">
            {memberships.map((m, i) => (
              <div
                key={m.id}
                className={`flex items-center gap-3 py-2.5 ${i < memberships.length - 1 ? "border-b border-border" : ""}`}
              >
                <InitialsAvatar name={m.user.fullName} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13.5px] font-semibold text-ink">{m.user.fullName}</div>
                  <div className="truncate text-[11.5px] text-ink-muted">{m.user.email}</div>
                </div>
                <Badge tone="indigo">{m.role}</Badge>
                <span className="w-16 shrink-0 text-right text-[11.5px] text-ink-faint">{m.status}</span>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}

function Row({ label, value, last = false }: { label: string; value: ReactNode; last?: boolean }) {
  return (
    <div className={`flex items-center justify-between py-2 text-[13.5px] ${last ? "" : "border-b border-border"}`}>
      <span className="text-ink-muted">{label}</span>
      <span className="font-medium text-ink">{value}</span>
    </div>
  );
}
