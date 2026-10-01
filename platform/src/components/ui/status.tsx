import type { BadgeProps } from "./badge.js";

/**
 * Single source of truth for status → label + badge tone across the whole
 * product. Before this file existed, every page kept its own
 * `STATUS_TONE: Record<string, …>` map and they disagreed with each other
 * (REQUESTED was coral on the appointments list but neutral on the detail
 * page; IN_CONSULTATION was coral in one place and indigo in another).
 *
 * Semantics (deliberate, shared with the Flutter `DoseStatusBadge` idea):
 *   ok      → completed / verified / available
 *   indigo  → confirmed or actively in progress
 *   warn    → needs attention (a request nobody has actioned yet)
 *   down    → cancelled / rejected / failed
 *   neutral → terminal-neutral (rescheduled, skipped)
 *
 * The tone alone never carries meaning: every badge renders the label text
 * too, and Badge pairs tint with text color, so states stay readable when
 * color can't be distinguished.
 */
type StatusTone = NonNullable<BadgeProps["tone"]>;

const STATUS: Record<string, { label: string; tone: StatusTone }> = {
  // Appointment lifecycle (appointments + queue state machines).
  REQUESTED: { label: "Requested", tone: "warn" },
  CONFIRMED: { label: "Confirmed", tone: "indigo" },
  CHECKED_IN: { label: "Checked in", tone: "indigo" },
  WAITING: { label: "Waiting", tone: "indigo" },
  IN_CONSULTATION: { label: "In consultation", tone: "coral" },
  COMPLETED: { label: "Completed", tone: "ok" },
  CANCELLED: { label: "Cancelled", tone: "down" },
  NO_SHOW: { label: "No show", tone: "down" },
  RESCHEDULED: { label: "Rescheduled", tone: "neutral" },

  // Queue board states (queue state machine; WAITING/IN_CONSULTATION above).
  CALLED: { label: "Called", tone: "coral" },
  SKIPPED: { label: "Skipped", tone: "neutral" },
  HOLD: { label: "On hold", tone: "warn" },

  // Clinic / organization states (OrganizationVerificationStatus enum).
  DRAFT: { label: "Draft", tone: "neutral" },
  PENDING_VERIFICATION: { label: "Pending verification", tone: "warn" },
  VERIFIED: { label: "Verified", tone: "ok" },
  REJECTED: { label: "Verification rejected", tone: "down" },
  ACTIVE: { label: "Active", tone: "ok" },
  INACTIVE: { label: "Inactive", tone: "neutral" },
  SUSPENDED: { label: "Suspended", tone: "down" },
};

/** Human label for a status code; falls back to the raw code when unknown so a
 * newly added backend state degrades to plain text, not a crash. */
export function statusLabel(status: string): string {
  return STATUS[status]?.label ?? status;
}

/** Badge tone for a status code; neutral for unknown codes. */
export function statusTone(status: string): StatusTone {
  return STATUS[status]?.tone ?? "neutral";
}
