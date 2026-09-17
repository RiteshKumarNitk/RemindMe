import { redirect } from "next/navigation";
import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { listPatients } from "@/modules/patients/service.js";
import { Button, Card, CardSubtitle, EmptyState, Field, InitialsAvatar, Input, Notice, SearchBar } from "@/components/ui/index.js";
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
    <div className="flex flex-col gap-7">
      <h1 className="font-display text-2xl font-bold text-ink">Patients</h1>

      <form>
        <SearchBar name="q" defaultValue={q} placeholder="Search by name, phone, or MRN…" />
      </form>

      {patients.length === 0 ? (
        <Card>
          <EmptyState title="No patients found." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {patients.map((p) => (
            <Link
              key={p.id}
              href={`/dashboard/${orgId}/patients/${p.id}`}
              className="flex items-center gap-3 rounded-2xl border border-border bg-card px-4 py-3 no-underline transition-colors hover:border-indigo"
            >
              <InitialsAvatar name={`${p.firstName} ${p.lastName}`} />
              <div className="min-w-0 flex-1">
                <div className="truncate text-[13.5px] font-semibold text-ink">
                  {p.firstName} {p.lastName}
                </div>
                <div className="truncate text-[11.5px] text-ink-muted">
                  {p.phone ?? "No phone"} {p.email ? `· ${p.email}` : ""}
                </div>
              </div>
              {p.mrn ? <span className="shrink-0 font-mono text-[11.5px] text-ink-faint">{p.mrn}</span> : null}
            </Link>
          ))}
        </div>
      )}

      <Card>
        <CardSubtitle>Register a patient</CardSubtitle>
        {error ? (
          <div className="mt-3">
            <Notice tone="down">{error}</Notice>
          </div>
        ) : null}
        <form action={createPatientAction.bind(null, orgId)} className="mt-4 flex max-w-md flex-col gap-4">
          <div className="grid grid-cols-2 gap-3">
            <Field label="First name">
              <Input name="firstName" required className="w-full" />
            </Field>
            <Field label="Last name">
              <Input name="lastName" required className="w-full" />
            </Field>
          </div>
          <Field label="Phone">
            <Input name="phone" className="w-full" />
          </Field>
          <Field label="Email">
            <Input name="email" type="email" className="w-full" />
          </Field>
          <Field label="Link to their platform login (optional)" hint="Only if they already have a DoseWise account">
            <Input name="ownerEmail" type="email" className="w-full" />
          </Field>
          <Button className="self-start">Register patient</Button>
        </form>
      </Card>
    </div>
  );
}
