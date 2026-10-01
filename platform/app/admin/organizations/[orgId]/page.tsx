import type { ReactNode } from "react";
import { requireSuperAdmin } from "@/lib/web-context.js";
import { getOrganizationDetail } from "@/modules/superadmin/service.js";
import { Badge, Button, Card, InitialsAvatar, Notice, statusLabel, statusTone } from "@/components/ui/index.js";
import { ConfirmSubmit } from "@/components/confirm-submit.js";
import { setOrganizationActiveAction, setOrganizationVerificationAction } from "./actions.js";

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

  const { org, verificationDocuments, memberships } = await getOrganizationDetail(ctx, orgId);

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
            value={<Badge tone={statusTone(org.verificationStatus)}>{statusLabel(org.verificationStatus)}</Badge>}
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
            {org.isActive ? (
              <ConfirmSubmit
                label="Suspend this clinic"
                variant="danger"
                confirmTitle={`Suspend ${org.name}?`}
                confirmMessage="All members lose access immediately, and the public profile is unpublished."
              />
            ) : (
              <Button>Reactivate this clinic</Button>
            )}
          </form>
          {org.verificationStatus === "PENDING_VERIFICATION" ? (
            <>
              <form action={setOrganizationVerificationAction.bind(null, orgId, "VERIFIED")}>
                <Button>Approve verification</Button>
              </form>
              <form action={setOrganizationVerificationAction.bind(null, orgId, "REJECTED")}>
                <ConfirmSubmit
                  label="Reject"
                  variant="danger"
                  confirmTitle={`Reject verification for ${org.name}?`}
                  confirmMessage="The clinic keeps operating but stays without the public Verified badge."
                />
              </form>
            </>
          ) : null}
        </div>
      </Card>

      {/* Verification evidence — what the request button on the clinic side
          uploads. Review these before approving/rejecting. */}
      <div>
        <h2 className="mb-3 font-display text-lg font-bold text-ink">
          Verification documents ({verificationDocuments.length})
        </h2>
        <Card>
          {verificationDocuments.length === 0 ? (
            <p className="py-3 text-sm text-ink-muted">
              No documents uploaded — decide without evidence or ask the clinic to attach some.
            </p>
          ) : (
            <div className="flex flex-col">
              {verificationDocuments.map((d, i) => (
                <div
                  key={d.id}
                  className={`flex flex-wrap items-center gap-3 py-2.5 ${i < verificationDocuments.length - 1 ? "border-b border-border" : ""}`}
                >
                  <div className="min-w-0 flex-1">
                    <a
                      href={`/api/orgs/${orgId}/verification-documents/${d.id}`}
                      className="block truncate text-[13.5px] font-medium text-indigo underline underline-offset-2"
                      title={d.fileName}
                    >
                      {d.fileName}
                    </a>
                    <div className="truncate text-[11.5px] text-ink-muted">
                      {(d.sizeBytes / 1024).toFixed(0)} KB · uploaded {new Date(d.createdAt).toLocaleDateString()}
                      {d.uploadedBy.fullName ? ` by ${d.uploadedBy.fullName}` : ""}
                    </div>
                  </div>
                  <span className="text-[11.5px] text-ink-faint">{d.mimeType}</span>
                </div>
              ))}
            </div>
          )}
        </Card>
      </div>

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
