import { AppError } from "@/lib/errors.js";
import { requireOrgContext } from "@/lib/web-context.js";
import { getPatient } from "@/modules/patients/service.js";
import { listAccessGrants } from "@/modules/family/service.js";
import { Badge, Button, Card, EmptyState, ErrorNote, Field, SectionTitle, Select, table, td, th } from "../../../ui.js";
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
    <div>
      <SectionTitle>
        {patient.firstName} {patient.lastName}
      </SectionTitle>
      <ErrorNote message={error} />

      <Card style={{ marginBottom: 20, maxWidth: 480 }}>
        <Row label="Phone" value={patient.phone ?? "—"} />
        <Row label="Email" value={patient.email ?? "—"} />
        <Row label="MRN" value={patient.mrn ?? "—"} />
        <Row
          label="Date of birth"
          value={patient.dateOfBirth ? new Date(patient.dateOfBirth).toLocaleDateString() : "—"}
        />
        <Row label="Sex" value={patient.sex ?? "—"} />
      </Card>

      {canManageGrants && (
        <Card style={{ maxWidth: 640 }}>
          <SectionTitle>Family / guardian access</SectionTitle>
          {grants.length === 0 ? (
            <EmptyState>No one else has access to this record yet.</EmptyState>
          ) : (
            <table style={table}>
              <thead>
                <tr>
                  <th style={th}>Grantee</th>
                  <th style={th}>Permissions</th>
                  <th style={th}>Expires</th>
                  <th style={th} />
                </tr>
              </thead>
              <tbody>
                {grants.map((g) => (
                  <tr key={g.id}>
                    <td style={td}>
                      {g.granteeUser.fullName}{" "}
                      <span style={{ color: "var(--ink-muted)" }}>({g.granteeUser.email})</span>
                    </td>
                    <td style={td}>
                      {g.revokedAt ? (
                        <Badge tone="muted">Revoked</Badge>
                      ) : (
                        g.permissions.map((p) => (
                          <span key={p} style={{ marginRight: 4, display: "inline-block" }}>
                            <Badge tone="indigo">{p.replaceAll("_", " ")}</Badge>
                          </span>
                        ))
                      )}
                    </td>
                    <td style={td}>{g.expiresAt ? new Date(g.expiresAt).toLocaleDateString() : "Never"}</td>
                    <td style={td}>
                      {!g.revokedAt && (
                        <form action={revokeAccessGrantAction.bind(null, orgId, patientId, g.id)}>
                          <Button variant="danger">Revoke</Button>
                        </form>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}

          <div style={{ marginTop: 16 }}>
            <SectionTitle>Grant access</SectionTitle>
            <form action={createAccessGrantAction.bind(null, orgId, patientId)}>
              <Field
                label="Their platform login email"
                name="granteeEmail"
                type="email"
                required
                placeholder="Must already have a DoseWise account"
              />
              <Select label="Relation (optional)" name="relation" defaultValue="">
                <option value="">—</option>
                <option value="SPOUSE">Spouse</option>
                <option value="FATHER">Father</option>
                <option value="MOTHER">Mother</option>
                <option value="CHILD">Child</option>
                <option value="GUARDIAN">Guardian</option>
                <option value="OTHER">Other</option>
              </Select>
              <div style={{ marginBottom: 12 }}>
                <div style={{ fontSize: 12, fontWeight: 700, color: "var(--ink-muted)", marginBottom: 4 }}>
                  Permissions
                </div>
                {PERMISSIONS.map((p) => (
                  <label key={p} style={{ display: "block", fontSize: 13, marginBottom: 4 }}>
                    <input type="checkbox" name="permissions" value={p} style={{ marginRight: 6 }} />
                    {p.replaceAll("_", " ")}
                  </label>
                ))}
              </div>
              <Field label="Expires (optional)" name="expiresAt" type="date" />
              <div style={{ marginTop: 8 }}>
                <Button variant="ghost">Grant access</Button>
              </div>
            </form>
          </div>
        </Card>
      )}
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        padding: "6px 0",
        borderBottom: "1px solid var(--border)",
        fontSize: 14,
      }}
    >
      <span style={{ color: "var(--ink-muted)" }}>{label}</span>
      <span>{value}</span>
    </div>
  );
}
