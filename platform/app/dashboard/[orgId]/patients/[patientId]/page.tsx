import type { ReactNode } from "react";
import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { getPatient } from "@/modules/patients/service.js";
import { listAccessGrants } from "@/modules/family/service.js";
import { Badge, Button, Card, CardSubtitle, EmptyState, Field, InitialsAvatar, Input, Notice, Select } from "@/components/ui/index.js";
import { createAccessGrantAction, revokeAccessGrantAction } from "./actions.js";

export const dynamic = "force-dynamic";

const PERMISSIONS = [
  "VIEW_PROFILE",
  "VIEW_APPOINTMENTS",
  "MANAGE_APPOINTMENTS",
  "VIEW_MEDICATIONS",
  "MANAGE_MEDICATIONS",
  "VIEW_DOCUMENTS",
] as const;

export default async function PatientDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string; patientId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId, patientId } = await params;
  const ctx = await requireOrgContext(orgId);
  const { error } = await searchParams;

  const patient = await getPatient(ctx, patientId);
  const canManageGrants =
    ctx.org!.role === "CLINIC_ADMIN" || (ctx.org!.role === "PATIENT" && patient.ownerUserId === ctx.userId);

  let grants: Awaited<ReturnType<typeof listAccessGrants>>["data"] = [];
  if (canManageGrants) {
    try {
      ({ data: grants } = await listAccessGrants(ctx, patientId));
    } catch (err) {
      if (!(err instanceof AppError)) throw err;
    }
  }

  return (
    <div className="flex flex-col gap-7">
      <div className="flex items-center gap-3">
        <InitialsAvatar name={`${patient.firstName} ${patient.lastName}`} />
        <h1 className="font-display text-2xl font-bold text-ink">
          {patient.firstName} {patient.lastName}
        </h1>
      </div>
      {error ? <Notice tone="down">{error}</Notice> : null}

      <Card className="max-w-lg">
        <div className="flex flex-col">
          <Row label="Phone" value={patient.phone ?? "—"} />
          <Row label="Email" value={patient.email ?? "—"} />
          <Row label="MRN" value={patient.mrn ?? "—"} />
          <Row label="Date of birth" value={patient.dateOfBirth ? new Date(patient.dateOfBirth).toLocaleDateString() : "—"} />
          <Row label="Sex" value={patient.sex ?? "—"} last />
        </div>
      </Card>

      {canManageGrants && (
        <div className="flex flex-col gap-7">
          <div>
            <h2 className="mb-3 font-display text-lg font-bold text-ink">Family / guardian access</h2>
            <Card>
              {grants.length === 0 ? (
                <EmptyState title="No one else has access to this record yet." />
              ) : (
                <div className="flex flex-col">
                  {grants.map((g, i) => (
                    <div
                      key={g.id}
                      className={`flex flex-wrap items-center gap-3 py-3 ${i < grants.length - 1 ? "border-b border-border" : ""}`}
                    >
                      <InitialsAvatar name={g.granteeUser.fullName} />
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-[13.5px] font-semibold text-ink">{g.granteeUser.fullName}</div>
                        <div className="truncate text-[11.5px] text-ink-muted">{g.granteeUser.email}</div>
                      </div>
                      <div className="flex flex-wrap gap-1.5">
                        {g.revokedAt ? (
                          <Badge tone="neutral">Revoked</Badge>
                        ) : (
                          g.permissions.map((p) => (
                            <Badge key={p} tone="indigo">
                              {p.replaceAll("_", " ")}
                            </Badge>
                          ))
                        )}
                      </div>
                      <span className="text-[11.5px] text-ink-faint">
                        {g.expiresAt ? `Expires ${new Date(g.expiresAt).toLocaleDateString()}` : "Never expires"}
                      </span>
                      {!g.revokedAt && (
                        <form action={revokeAccessGrantAction.bind(null, orgId, patientId, g.id)}>
                          <Button variant="danger" size="sm">
                            Revoke
                          </Button>
                        </form>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </Card>
          </div>

          <Card className="max-w-md">
            <CardSubtitle>Grant access</CardSubtitle>
            <form action={createAccessGrantAction.bind(null, orgId, patientId)} className="mt-4 flex flex-col gap-4">
              <Field label="Their platform login email" hint="Must already have a DoseWise account">
                <Input name="granteeEmail" type="email" required className="w-full" />
              </Field>
              <Field label="Relation (optional)">
                <Select name="relation" defaultValue="" className="w-full">
                  <option value="">—</option>
                  <option value="SPOUSE">Spouse</option>
                  <option value="FATHER">Father</option>
                  <option value="MOTHER">Mother</option>
                  <option value="CHILD">Child</option>
                  <option value="GUARDIAN">Guardian</option>
                  <option value="OTHER">Other</option>
                </Select>
              </Field>
              <div>
                <div className="mb-2 text-[11px] font-semibold uppercase tracking-wide text-ink-faint">Permissions</div>
                <div className="flex flex-col gap-2">
                  {PERMISSIONS.map((p) => (
                    <label key={p} className="flex items-center gap-2 text-[13px] text-ink">
                      <input type="checkbox" name="permissions" value={p} className="h-4 w-4 accent-indigo" />
                      {p.replaceAll("_", " ")}
                    </label>
                  ))}
                </div>
              </div>
              <Field label="Expires (optional)">
                <Input name="expiresAt" type="date" className="w-full" />
              </Field>
              <Button variant="ghost" className="self-start">
                Grant access
              </Button>
            </form>
          </Card>
        </div>
      )}
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
