import { requireWebUser } from "@/lib/web-context.js";
import { Button, Card, CardSubtitle, CardTitle, Field, Input, Notice, Select, Stepper } from "@/components/ui/index.js";
import { createOrgAction } from "./actions.js";

export const dynamic = "force-dynamic";

/**
 * Guided setup, step 1 (request §10): organization basics + primary
 * location. Deliberately NOT one huge form — the org row (with its location
 * and settings) is created immediately on submit, so every later step
 * operates on real data and "saving progress" is automatic: leaving after
 * this step loses nothing, and the setup checklist tracks the rest.
 */
export default async function NewClinicPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string }>;
}) {
  await requireWebUser();
  const { error } = await searchParams;

  return (
    <main style={{ maxWidth: 560, margin: "48px auto", padding: "0 20px" }}>
      <Stepper
        steps={[
          { key: "basics", label: "Basics & location" },
          { key: "profile", label: "Public profile" },
          { key: "doctors", label: "Doctors" },
          { key: "services", label: "Services" },
          { key: "review", label: "Review & publish" },
        ]}
        current={0}
        className="mb-6"
      />

      <h1 className="text-xl font-semibold text-ink">Create a clinic</h1>
      <p className="mt-1 text-sm text-ink-muted">
        Two minutes to set up — you can finish the rest of the profile any time.
      </p>

      <div className="mt-5">
        <Card>
          <CardTitle>Organization basics</CardTitle>
          {error ? (
            <div className="mt-3">
              <Notice tone="down">{error}</Notice>
            </div>
          ) : null}
          <form action={createOrgAction} className="mt-4 flex flex-col gap-4">
            <Field label="Clinic name" hint="The name patients will see.">
              <Input name="name" required placeholder="Sunrise Family Clinic" />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field
                label="URL slug"
                hint="Lowercase letters, numbers, dashes — used in your public profile link."
              >
                <Input name="slug" required placeholder="sunrise-clinic" />
              </Field>
              <Field label="Timezone">
                <Select name="timezone" defaultValue="Asia/Kolkata">
                  <option value="Asia/Kolkata">Asia/Kolkata (IST)</option>
                  <option value="Asia/Dubai">Asia/Dubai</option>
                  <option value="Asia/Singapore">Asia/Singapore</option>
                  <option value="Europe/London">Europe/London</option>
                  <option value="America/New_York">America/New_York</option>
                  <option value="America/Los_Angeles">America/Los_Angeles</option>
                </Select>
              </Field>
            </div>

            <div className="mt-2 border-t border-border pt-4">
              <CardSubtitle>Primary location</CardSubtitle>
              <p className="mt-1 text-[13px] text-ink-muted">
                Where patients will find you. You can add more branches later.
              </p>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Location name">
                <Input name="locationName" required placeholder="Main branch" />
              </Field>
              <Field label="City">
                <Input name="locationCity" placeholder="Jaipur" />
              </Field>
            </div>
            <Field label="Street address">
              <Input name="locationAddress" placeholder="12 Station Road" />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="State">
                <Input name="locationState" placeholder="Rajasthan" />
              </Field>
              <Field label="Postal code">
                <Input name="locationPostalCode" placeholder="302001" />
              </Field>
            </div>

            <div className="mt-1 flex items-center justify-between gap-3">
              <p className="text-[12px] text-ink-faint">
                Your clinic is private until you choose to publish it.
              </p>
              <Button>Create clinic</Button>
            </div>
          </form>
        </Card>
      </div>
    </main>
  );
}
