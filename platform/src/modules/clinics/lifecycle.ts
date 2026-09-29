/**
 * Composed listing lifecycle (request §15) — the dashboard's single vocabulary
 * for "where is this clinic in its journey to being publicly visible".
 *
 * There is deliberately **no second state machine here**. The backend's real
 * state is the pair (`OrganizationVerificationStatus`, `isPubliclyListed`)
 * plus the readiness predicate `canPublishOrganization`; this helper only
 * composes those existing fields into one human label + badge tone so the
 * owner dashboard, profile page and admin surfaces all say the same thing.
 * Publish/unpublish/request-verification remain the only transitions, and
 * they keep enforcing their own guards server-side.
 *
 * Mapping (see docs/DASHBOARD_AUDIT.md §5):
 *   suspended                       → Suspended (superadmin isActive=false)
 *   REJECTED                        → Rejected — fix & resubmit
 *   PENDING_VERIFICATION            → Pending verification
 *   VERIFIED + listed               → Published
 *   VERIFIED + !listed              → Verified — not listed
 *   ready + !listed                 → Ready to publish
 *   otherwise                       → Draft — incomplete
 */

import type { BadgeProps } from "@/components/ui/badge.js";
import { canPublishOrganization } from "./publish.js";

export type LifecycleTone = NonNullable<BadgeProps["tone"]>;

export interface LifecycleInput {
  verificationStatus: string;
  isPubliclyListed: boolean;
  isActive: boolean;
  // The same shape canPublishOrganization consumes.
  orgType: string | null;
  tagline: string | null;
  about: string | null;
  publicPhone: string | null;
  publicEmail: string | null;
  activeLocationCount: number;
  name?: string;
}

export interface Lifecycle {
  code:
    | "SUSPENDED"
    | "REJECTED"
    | "PENDING_VERIFICATION"
    | "PUBLISHED"
    | "VERIFIED_UNLISTED"
    | "READY_TO_PUBLISH"
    | "DRAFT";
  label: string;
  tone: LifecycleTone;
  /** Short next-step hint for the surface that shows the label. */
  hint: string;
  /** Publish-readiness reasons, surfaced when not ready. */
  readinessReasons: string[];
}

export function listingLifecycle(org: LifecycleInput): Lifecycle {
  const readiness = canPublishOrganization({
    name: org.name ?? "",
    orgType: org.orgType,
    tagline: org.tagline,
    about: org.about,
    publicPhone: org.publicPhone,
    publicEmail: org.publicEmail,
    activeLocationCount: org.activeLocationCount,
  });

  if (!org.isActive) {
    return {
      code: "SUSPENDED",
      label: "Suspended",
      tone: "down",
      hint: "This clinic has been suspended by the platform.",
      readinessReasons: readiness.reasons,
    };
  }
  if (org.verificationStatus === "REJECTED") {
    return {
      code: "REJECTED",
      label: "Rejected — fix & resubmit",
      tone: "down",
      hint: "Update the profile, then request verification again.",
      readinessReasons: readiness.reasons,
    };
  }
  if (org.verificationStatus === "PENDING_VERIFICATION") {
    return {
      code: "PENDING_VERIFICATION",
      label: "Pending verification",
      tone: "warn",
      hint: "The DoseWise team is reviewing this profile.",
      readinessReasons: readiness.reasons,
    };
  }
  if (org.verificationStatus === "VERIFIED" && org.isPubliclyListed) {
    return {
      code: "PUBLISHED",
      label: "Published",
      tone: "ok",
      hint: "Live on the DoseWise website and patient app.",
      readinessReasons: readiness.reasons,
    };
  }
  if (org.verificationStatus === "VERIFIED") {
    return {
      code: "VERIFIED_UNLISTED",
      label: "Verified — not listed",
      tone: "indigo",
      hint: "Verified, but patients can't find it until you publish.",
      readinessReasons: readiness.reasons,
    };
  }
  if (readiness.ready) {
    return {
      code: "READY_TO_PUBLISH",
      label: "Ready to publish",
      tone: "indigo",
      hint: "Everything needed for public discovery is in place.",
      readinessReasons: [],
    };
  }
  return {
    code: "DRAFT",
    label: "Draft — incomplete",
    tone: "neutral",
    hint: readiness.reasons[0] ?? "Complete the profile to publish.",
    readinessReasons: readiness.reasons,
  };
}
