import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { getOrganization } from "@/modules/clinics/service.js";
import { canPublishOrganization } from "@/modules/clinics/publish.js";
import { Badge, Button, Card, CardSubtitle, CardTitle, Field, Input, Select } from "@/components/ui/index.js";
import { publishAction, saveProfileAction, unpublishAction } from "./actions.js";

export const dynamic = "force-dynamic";

const ORG_TYPES: Array<{ value: string; label: string }> = [
  { value: "HOSPITAL", label: "Hospital" },
  { value: "CLINIC", label: "Clinic" },
  { value: "DIAGNOSTIC_CENTER", label: "Diagnostic center" },
  { value: "POLYCLINIC", label: "Polyclinic" },
  { value: "OTHER", label: "Other" },
];

export default async function OrganizationProfilePage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string; saved?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);
  const { error, saved } = await searchParams;

  const org = await getOrganization(ctx);
  const readiness = canPublishOrganization({
    name: org.name,
    orgType: org.orgType,
    tagline: org.tagline,
    about: org.about,
    publicPhone: org.publicPhone,
    publicEmail: org.publicEmail,
    activeLocationCount: org.locations.length,
  });

  return (
    <div className="flex max-w-4xl flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-ink">Organization profile</h1>
        <p className="mt-1 text-sm text-ink-muted">
          This is what patients will eventually see when public hospital/doctor discovery ships.
          Fill it in now so your clinic is ready to publish.
        </p>
      </div>

      {error ? (
        <div className="rounded-control border border-down/30 bg-down/5 px-4 py-3 text-sm text-down">
          {error}
        </div>
      ) : null}
      {saved ? (
        <div className="rounded-control border border-ok/30 bg-ok/5 px-4 py-3 text-sm text-ok">
          Saved.
        </div>
      ) : null}

      {/* Public profile preview */}
      <Card>
        <div className="flex items-start justify-between gap-4">
          <div>
            <CardSubtitle>Preview — how this will look publicly</CardSubtitle>
            <CardTitle className="mt-1 text-lg">{org.name}</CardTitle>
            <p className="mt-1 text-sm text-ink-muted">
              {org.tagline || "No short description yet."}
            </p>
          </div>
          <div className="flex flex-col items-end gap-1.5">
            <Badge tone={org.isPubliclyListed ? "ok" : "neutral"}>
              {org.isPubliclyListed ? "Listed publicly" : "Not listed yet"}
            </Badge>
            <Badge tone={org.verificationStatus === "VERIFIED" ? "indigo" : "neutral"}>
              {org.verificationStatus === "VERIFIED" ? "Verified" : "Not verified yet"}
            </Badge>
          </div>
        </div>
        <div className="mt-4 grid grid-cols-2 gap-3 text-sm text-ink-muted sm:grid-cols-4">
          <div>
            <div className="text-ink">{ORG_TYPES.find((t) => t.value === org.orgType)?.label ?? "—"}</div>
            <div>Type</div>
          </div>
          <div>
            <div className="text-ink">{org.locations.length}</div>
            <div>Location{org.locations.length === 1 ? "" : "s"}</div>
          </div>
          <div>
            <div className="text-ink">{org.publicPhone || org.publicEmail || "—"}</div>
            <div>Contact</div>
          </div>
          <div>
            <div className="text-ink">{org.website || "—"}</div>
            <div>Website</div>
          </div>
        </div>
        {org.about ? <p className="mt-4 text-sm text-ink">{org.about}</p> : null}
      </Card>

      {/* Publish gate */}
      <Card>
        <CardTitle>{org.isPubliclyListed ? "Public listing" : "Ready to publish?"}</CardTitle>
        {readiness.ready ? (
          <p className="mt-2 text-sm text-ink-muted">
            This profile has everything needed to appear in public discovery once that feature
            ships.
          </p>
        ) : (
          <ul className="mt-2 list-disc pl-5 text-sm text-ink-muted">
            {readiness.reasons.map((reason) => (
              <li key={reason}>{reason}</li>
            ))}
          </ul>
        )}
        <div className="mt-4">
          {org.isPubliclyListed ? (
            <form action={unpublishAction.bind(null, orgId)}>
              <Button variant="secondary">Unpublish</Button>
            </form>
          ) : (
            <form action={publishAction.bind(null, orgId)}>
              <Button disabled={!readiness.ready}>Publish profile</Button>
            </form>
          )}
        </div>
      </Card>

      {/* Edit form */}
      <Card>
        <CardTitle>Edit profile</CardTitle>
        <form action={saveProfileAction.bind(null, orgId)} className="mt-4 flex flex-col gap-4">
          <Field label="Organization type">
            <Select name="orgType" defaultValue={org.orgType ?? ""}>
              <option value="">Choose one…</option>
              {ORG_TYPES.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="Short description" hint="One line — shown under the clinic name.">
            <Input name="tagline" maxLength={200} defaultValue={org.tagline ?? ""} placeholder="Family medicine & pediatrics" />
          </Field>
          <Field label="About">
            <textarea
              name="about"
              maxLength={4000}
              defaultValue={org.about ?? ""}
              rows={4}
              className="rounded-control border border-border bg-card px-3 py-2 text-sm text-ink outline-none focus:border-indigo"
              placeholder="Tell patients about your clinic…"
            />
          </Field>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Field label="Public phone">
              <Input name="publicPhone" defaultValue={org.publicPhone ?? ""} placeholder="+91 98765 43210" />
            </Field>
            <Field label="Public email">
              <Input name="publicEmail" type="email" defaultValue={org.publicEmail ?? ""} placeholder="hello@clinic.example" />
            </Field>
          </div>
          <Field label="Website" hint="Optional.">
            <Input name="website" type="url" defaultValue={org.website ?? ""} placeholder="https://clinic.example" />
          </Field>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Field label="Logo URL" hint="Image upload isn't built yet — paste a hosted image link for now.">
              <Input name="logoUrl" type="url" defaultValue={org.logoUrl ?? ""} placeholder="https://…" />
            </Field>
            <Field label="Cover image URL" hint="Same — a hosted link for now.">
              <Input name="coverImageUrl" type="url" defaultValue={org.coverImageUrl ?? ""} placeholder="https://…" />
            </Field>
          </div>
          <div className="mt-1">
            <Button type="submit">Save profile</Button>
          </div>
        </form>
      </Card>

      <p className="text-sm text-ink-muted">
        Locations, doctors, staff, and appointment types are managed on the{" "}
        <a className="text-indigo underline" href={`/dashboard/${orgId}/settings`}>
          Settings
        </a>{" "}
        page.
      </p>
    </div>
  );
}
