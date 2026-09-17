import Link from "next/link";
import { requireOrgContext } from "@/lib/web-context.js";
import { listDoctors } from "@/modules/doctors/service.js";
import { Badge, Button, Card, CardSubtitle, EmptyState, Field, InitialsAvatar, Input, Notice } from "@/components/ui/index.js";
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
    <div className="flex flex-col gap-7">
      <h1 className="font-display text-2xl font-bold text-ink">Doctors</h1>

      {doctors.length === 0 ? (
        <Card>
          <EmptyState title="No doctors yet." />
        </Card>
      ) : (
        <div className="flex flex-col gap-2.5">
          {doctors.map((d) => (
            <Card key={d.id} className="p-4!">
              <div className="flex items-center gap-3">
                <InitialsAvatar name={d.displayName} />
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13.5px] font-semibold text-ink">{d.displayName}</div>
                  <div className="truncate text-[11.5px] text-ink-muted">
                    {d.specialty ?? "No specialty set"} · {d.consultationDurationMin} min consults
                  </div>
                </div>
                <Badge tone={d.isActive ? "ok" : "neutral"}>{d.isActive ? "Active" : "Inactive"}</Badge>
              </div>
              <div className="mt-3 flex gap-4 border-t border-border pt-3 text-[12.5px] font-semibold">
                <Link href={`/dashboard/${orgId}/doctors/${d.id}/availability`} className="text-indigo no-underline">
                  Availability
                </Link>
                <Link href={`/dashboard/${orgId}/doctors/${d.id}/profile`} className="text-indigo no-underline">
                  Profile
                </Link>
              </div>
            </Card>
          ))}
        </div>
      )}

      {isAdmin && (
        <Card>
          <CardSubtitle>Add a doctor</CardSubtitle>
          {error ? (
            <div className="mt-3">
              <Notice tone="down">{error}</Notice>
            </div>
          ) : null}
          <form action={createDoctorAction.bind(null, orgId)} className="mt-4 flex max-w-md flex-col gap-4">
            <Field label="Full name">
              <Input name="fullName" required className="w-full" />
            </Field>
            <Field label="Email">
              <Input name="email" type="email" required className="w-full" />
            </Field>
            <Field label="Display name (shown to patients)">
              <Input name="displayName" required className="w-full" />
            </Field>
            <Field label="Specialty">
              <Input name="specialty" placeholder="General Medicine" className="w-full" />
            </Field>
            <Field label="Consultation length (minutes)">
              <Input name="consultationDurationMin" type="number" defaultValue="15" className="w-full" />
            </Field>
            <Button className="self-start">Add doctor</Button>
          </form>
        </Card>
      )}
    </div>
  );
}
