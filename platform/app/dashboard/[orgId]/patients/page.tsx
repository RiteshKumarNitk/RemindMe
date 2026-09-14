import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { listPatients } from "@/modules/patients/service.js";
import { Button, Card, EmptyState, ErrorNote, Field, SectionTitle, table, td, th } from "../../ui.js";
import { createPatientAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function PatientsPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string; q?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (!["CLINIC_ADMIN", "RECEPTIONIST"].includes(ctx.org!.role)) redirect(`/dashboard/${orgId}`);
  const { error, q } = await searchParams;
  const { data: patients } = await listPatients(ctx, { q, limit: 50 });

  return (
    <div>
      <SectionTitle>Patients</SectionTitle>
      <Card style={{ marginBottom: 20 }}>
        <form style={{ marginBottom: 14 }}>
          <Field label="Search by name, phone or MRN" name="q" defaultValue={q} placeholder="Search…" />
        </form>
        {patients.length === 0 ? (
          <EmptyState>No patients found.</EmptyState>
        ) : (
          <table style={table}>
            <thead>
              <tr>
                <th style={th}>Name</th>
                <th style={th}>Phone</th>
                <th style={th}>Email</th>
                <th style={th}>MRN</th>
              </tr>
            </thead>
            <tbody>
              {patients.map((p) => (
                <tr key={p.id}>
                  <td style={td}>
                    {p.firstName} {p.lastName}
                  </td>
                  <td style={td}>{p.phone ?? "—"}</td>
                  <td style={td}>{p.email ?? "—"}</td>
                  <td style={td}>{p.mrn ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </Card>

      <Card style={{ maxWidth: 420 }}>
        <SectionTitle>Register a patient</SectionTitle>
        <ErrorNote message={error} />
        <form action={createPatientAction.bind(null, orgId)}>
          <Field label="First name" name="firstName" required />
          <Field label="Last name" name="lastName" required />
          <Field label="Phone" name="phone" />
          <Field label="Email" name="email" type="email" />
          <Field
            label="Link to their platform login (optional)"
            name="ownerEmail"
            type="email"
            placeholder="Only if they already have a DoseWise account"
          />
          <div style={{ marginTop: 8 }}>
            <Button>Register patient</Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
