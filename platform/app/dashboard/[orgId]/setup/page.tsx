import Link from "next/link";
import { redirect } from "next/navigation";
import { requireOrgContext } from "@/lib/web-context.js";
import { getOrgInsights } from "@/modules/clinics/insights.js";
import {
  Badge,
  Button,
  Card,
  CardSubtitle,
  CardTitle,
  CompletionMeter,
  LinkButton,
  Notice,
  Stepper,
} from "@/components/ui/index.js";
import {
  publishSetupAction,
  requestVerificationSetupAction,
  unpublishSetupAction,
} from "./actions.js";

export const dynamic = "force-dynamic";

/**
 * Guided setup checklist (request §7/§10/§14/§15). Progress IS the org's
 * real data — nothing is stored about "the flow itself", so leaving and
 * returning at any time is lossless by construction. Every step card links
 * to the page that completes it; the final step reuses the existing
 * publish/verification endpoints (their server-side guards remain the
 * authority).
 */
export default async function SetupPage({
  params,
  searchParams,
}: {
  params: Promise<{ orgId: string }>;
  searchParams: Promise<{ error?: string }>;
}) {
  const { orgId } = await params;
  const ctx = await requireOrgContext(orgId);
  if (ctx.org!.role !== "CLINIC_ADMIN") redirect(`/dashboard/${orgId}`);
  const { error } = await searchParams;

  const insights = await getOrgInsights(ctx, orgId);
  const doneKeys = new Set(
    insights.completeness.items.filter((i) => i.done).map((i) => i.key),
  );

  const steps: Array<{ key: string; label: string; href: string; done: boolean; description: string }> = [
    {
      key: "profile",
      label: "Public profile",
      href: `/dashboard/${orgId}/profile`,
      done: doneKeys.has("orgType") && doneKeys.has("description") && doneKeys.has("contact"),
      description: "Type, description, public phone or email, logo and cover image.",
    },
    {
      key: "location",
      label: "Locations",
      href: `/dashboard/${orgId}/settings`,
      done: doneKeys.has("location") && doneKeys.has("address"),
      description: "At least one branch with a real address — patients search by city.",
    },
    {
      key: "doctors",
      label: "Doctors",
      href: `/dashboard/${orgId}/doctors`,
      done: doneKeys.has("doctor") && doneKeys.has("doctorPublic"),
      description: "Add each doctor's specialty, experience, languages and fee.",
    },
    {
      key: "services",
      label: "Services",
      href: `/dashboard/${orgId}/settings`,
      done: doneKeys.has("types"),
      description: "Appointment types patients can choose when booking.",
    },
    {
      key: "availability",
      label: "Availability",
      href: `/dashboard/${orgId}/doctors`,
      done: insights.counts.activeDoctors > 0 && insights.counts.doctorsWithoutAvailability === 0,
      description: "Weekly hours for every doctor — their calendar books nothing without it.",
    },
    {
      key: "listing",
      label: "Review & publish",
      href: `/dashboard/${orgId}/profile`,
      done: insights.org.isPubliclyListed,
      description: "Preview the public profile, then publish and request verification.",
    },
  ];

  const doneCount = steps.filter((s) => s.done).length;
  // findIndex returns -1 once everything is done; clamp to the last step so
  // the stepper shows a fully-complete run instead of dropping every marker.
  const firstUndone = steps.findIndex((s) => !s.done);
  const currentStep = firstUndone === -1 ? steps.length - 1 : firstUndone;

  return (
    <div className="flex max-w-3xl flex-col gap-6">
      <div>
        <h1 className="font-display text-2xl font-bold text-ink">Clinic setup</h1>
        <p className="mt-1 text-sm text-ink-muted">
          Finish these steps to appear on the DoseWise website and patient app. Progress saves
          automatically — leave and come back any time.
        </p>
      </div>

      {error ? <Notice tone="down">{error}</Notice> : null}

      <Stepper
        steps={steps.map((s, i) => ({ key: s.key, label: s.label, href: s.done ? s.href : undefined }))}
        current={currentStep}
      />

      <Card>
        <div className="flex flex-wrap items-center justify-between gap-3">
          <CardTitle>Profile completeness</CardTitle>
          <span className="text-[12.5px] text-ink-faint">
            {doneCount} of {steps.length} setup steps done
          </span>
        </div>
        <div className="mt-3">
          <CompletionMeter completeness={insights.completeness} />
        </div>
      </Card>

      <div className="flex flex-col gap-3">
        {steps.map((step, i) => {
          const state = step.done ? "done" : i === currentStep ? "current" : "upcoming";
          return (
            <Link
              key={step.key}
              href={step.href}
              className={`flex items-start gap-3.5 rounded-card border px-4 py-3.5 no-underline transition-colors ${
                state === "current"
                  ? "border-indigo/40 bg-indigo/5 hover:border-indigo"
                  : "border-border bg-card hover:border-indigo/40"
              }`}
            >
              <span
                aria-hidden
                className={`mt-0.5 flex h-6.5 w-6.5 shrink-0 items-center justify-center rounded-full border text-[12px] font-bold ${
                  state === "done"
                    ? "border-ok bg-ok text-white"
                    : state === "current"
                      ? "border-indigo bg-indigo text-white"
                      : "border-border bg-card text-ink-faint"
                }`}
              >
                {state === "done" ? "✓" : i + 1}
              </span>
              <span className="min-w-0 flex-1">
                <span className="flex items-center gap-2">
                  <span className="text-[14px] font-semibold text-ink">{step.label}</span>
                  {state === "done" ? <Badge tone="ok">Done</Badge> : null}
                  {state === "current" ? <Badge tone="indigo">Up next</Badge> : null}
                </span>
                <span className="mt-0.5 block text-[13px] text-ink-muted">{step.description}</span>
              </span>
            </Link>
          );
        })}
      </div>

      {/* Listing step (§15) — reuses the existing publish/verification services. */}
      <Card>
        <CardTitle>Public listing</CardTitle>
        <div className="mt-2 flex flex-wrap items-center gap-2">
          <Badge tone={insights.lifecycle.tone}>{insights.lifecycle.label}</Badge>
          <LinkButton variant="ghost" size="sm" href={`/hospitals/${insights.org.slug}`}>
            Preview public profile ↗
          </LinkButton>
        </div>
        {insights.lifecycle.readinessReasons.length > 0 ? (
          <ul className="mt-3 list-disc pl-5 text-[13px] text-ink-muted">
            {insights.lifecycle.readinessReasons.map((r) => (
              <li key={r}>{r}</li>
            ))}
          </ul>
        ) : (
          <p className="mt-3 text-[13px] text-ink-muted">{insights.lifecycle.hint}</p>
        )}

        <div className="mt-4 flex flex-wrap gap-2">
          {insights.org.isPubliclyListed ? (
            <form action={unpublishSetupAction.bind(null, orgId)}>
              <Button variant="secondary" type="submit">
                Unpublish
              </Button>
            </form>
          ) : (
            <form action={publishSetupAction.bind(null, orgId)}>
              <Button type="submit">Publish clinic</Button>
            </form>
          )}
          {insights.org.verificationStatus === "DRAFT" || insights.org.verificationStatus === "REJECTED" ? (
            <form action={requestVerificationSetupAction.bind(null, orgId)}>
              <Button variant="secondary" type="submit">
                Request verification
              </Button>
            </form>
          ) : null}
        </div>
        <p className="mt-3 text-[12px] text-ink-faint">
          Publishing makes the clinic discoverable. Verification adds the verified badge after a
          DoseWise review — the two are separate.
        </p>
      </Card>

      <p className="text-[13px] text-ink-muted">
        Done with setup? Head to the{" "}
        <Link href={`/dashboard/${orgId}`} className="text-indigo underline">
          dashboard
        </Link>
        .
      </p>
    </div>
  );
}
