import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { getDoctor } from "@/modules/doctors/service.js";
import { Badge, Button, Card, CardSubtitle, CardTitle, Field, Input } from "@/components/ui/index.js";
import { saveDoctorProfileAction } from "./actions.js";

export const dynamic = "force-dynamic";

export default async function DoctorProfilePage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string; doctorId: string }>;
  searchParams: Promise<{ error?: string; saved?: string }>;
}) {
  const { orgId, doctorId } = await params;
  const ctx = await requireOrgContext(orgId);
  const doctor = await getDoctor(ctx, doctorId);

  const canEdit = ctx.org!.role === "CLINIC_ADMIN" || doctor.userId === ctx.userId;
  if (!canEdit) redirect(`/dashboard/${orgId}/doctors`);

  const { error, saved } = await searchParams;
  const feeRupees = doctor.consultationFeeMinor != null ? (doctor.consultationFeeMinor / 100).toFixed(2) : "";

  return (
    <div className="flex max-w-3xl flex-col gap-6">
      <div>
        <h1 className="text-xl font-semibold text-ink">Professional profile</h1>
        <p className="mt-1 text-sm text-ink-muted">
          Shown on {doctor.displayName}&rsquo;s profile once public doctor discovery ships.
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

      <Card>
        <div className="flex items-start justify-between gap-4">
          <div>
            <CardSubtitle>Preview</CardSubtitle>
            <CardTitle className="mt-1 text-lg">{doctor.displayName}</CardTitle>
            <p className="mt-1 text-sm text-ink-muted">
              {doctor.specialty ?? "No specialty set"}
              {doctor.yearsOfExperience ? ` · ${doctor.yearsOfExperience} years experience` : ""}
            </p>
            {doctor.qualifications ? <p className="mt-1 text-sm text-ink-muted">{doctor.qualifications}</p> : null}
            {doctor.languages.length ? (
              <p className="mt-1 text-sm text-ink-muted">{doctor.languages.join(" · ")}</p>
            ) : null}
            {doctor.bio ? <p className="mt-3 text-sm text-ink">{doctor.bio}</p> : null}
          </div>
          <Badge tone={doctor.isPubliclyListed ? "ok" : "neutral"}>
            {doctor.isPubliclyListed ? "Listed publicly" : "Not listed yet"}
          </Badge>
        </div>
      </Card>

      <Card>
        <CardTitle>Edit</CardTitle>
        <form
          action={saveDoctorProfileAction.bind(null, orgId, doctorId)}
          className="mt-4 flex flex-col gap-4"
        >
          <Field label="Qualifications" hint="e.g. MBBS, MD (Cardiology)">
            <Input name="qualifications" maxLength={500} defaultValue={doctor.qualifications ?? ""} />
          </Field>
          <Field label="Years of experience">
            <Input
              name="yearsOfExperience"
              type="number"
              min={0}
              max={80}
              defaultValue={doctor.yearsOfExperience ?? ""}
            />
          </Field>
          <Field label="Languages" hint="Comma-separated, e.g. English, Hindi">
            <Input name="languages" defaultValue={doctor.languages.join(", ")} />
          </Field>
          <Field label="Consultation fee" hint="In your local currency — leave blank if not charged separately.">
            <Input name="consultationFee" type="number" min={0} step="0.01" defaultValue={feeRupees} />
          </Field>
          <Field label="Bio">
            <textarea
              name="bio"
              maxLength={2000}
              defaultValue={doctor.bio ?? ""}
              rows={4}
              className="rounded-control border border-border bg-card px-3 py-2 text-sm text-ink outline-none focus:border-indigo"
              placeholder="Tell patients about your practice…"
            />
          </Field>
          <Field label="Photo URL" hint="Image upload isn't built yet — paste a hosted image link for now.">
            <Input name="photoUrl" type="url" defaultValue={doctor.photoUrl ?? ""} placeholder="https://…" />
          </Field>
          <label className="flex items-center gap-2 text-sm text-ink">
            <input type="checkbox" name="isPubliclyListed" defaultChecked={doctor.isPubliclyListed} />
            List this doctor in public discovery once it ships
          </label>
          <div className="mt-1">
            <Button type="submit">Save profile</Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
