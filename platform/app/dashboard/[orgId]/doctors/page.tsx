import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { listDoctors } from "@/modules/doctors/service.js";
import { Button, Card, EmptyState, ErrorNote, Field, SectionTitle, Table, td, th } from "../../ui.js";
import { createDoctorAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function DoctorsPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  const { error } = await searchParams;
  const doctors = await listDoctors(ctx);
  const isAdmin = ctx.org!.role === "CLINIC_ADMIN";

  return (
    <div>
      <SectionTitle>Doctors</SectionTitle>
      <Card style={{ marginBottom: 20 }}>
        {doctors.length === 0 ? (
          <EmptyState>No doctors yet.</EmptyState>
        ) : (
          <Table>
            <thead>
              <tr>
                <th style={th}>Name</th>
                <th style={th}>Specialty</th>
                <th style={th}>Consult (min)</th>
                <th style={th}>Status</th>
                <th style={th} />
              </tr>
            </thead>
            <tbody>
              {doctors.map((d) => (
                <tr key={d.id}>
                  <td style={td}>{d.displayName}</td>
                  <td style={td}>{d.specialty ?? "—"}</td>
                  <td style={td}>{d.consultationDurationMin}</td>
                  <td style={td}>{d.isActive ? "Active" : "Inactive"}</td>
                  <td style={td}>
                    <Link href={`/dashboard/${orgId}/doctors/${d.id}/availability`}>Availability</Link>
                    {" · "}
                    <Link href={`/dashboard/${orgId}/doctors/${d.id}/profile`}>Profile</Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </Table>
        )}
      </Card>

      {isAdmin && (
        <Card style={{ maxWidth: 420 }}>
          <SectionTitle>Add a doctor</SectionTitle>
          <ErrorNote message={error} />
          <form action={createDoctorAction.bind(null, orgId)}>
            <Field label="Full name" name="fullName" required />
            <Field label="Email" name="email" type="email" required />
            <Field label="Display name (shown to patients)" name="displayName" required />
            <Field label="Specialty" name="specialty" placeholder="General Medicine" />
            <Field label="Consultation length (minutes)" name="consultationDurationMin" type="number" defaultValue="15" />
            <div style={{ marginTop: 8 }}>
              <Button>Add doctor</Button>
            </div>
          </form>
        </Card>
      )}
    </div>
  );
}
