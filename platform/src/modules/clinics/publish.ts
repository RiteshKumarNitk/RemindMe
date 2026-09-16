/**
 * Pure validation for "is this organization's profile complete enough to
 * appear in public discovery" (PRODUCT_EVOLUTION_PLAN.md §15 Phase 3). Kept
 * separate from the DB-touching service function so it's unit-testable
 * without a database connection.
 */
export interface PublishReadinessInput {
  name: string;
  orgType: string | null;
  tagline: string | null;
  about: string | null;
  publicPhone: string | null;
  publicEmail: string | null;
  activeLocationCount: number;
}

export interface PublishReadiness {
  ready: boolean;
  reasons: string[];
}

export function canPublishOrganization(input: PublishReadinessInput): PublishReadiness {
  const reasons: string[] = [];

  if (!input.name.trim()) {
    reasons.push("Add a clinic name.");
  }
  if (!input.orgType) {
    reasons.push("Choose an organization type.");
  }
  if (!input.tagline?.trim() && !input.about?.trim()) {
    reasons.push("Add a short description or an About section.");
  }
  if (!input.publicPhone?.trim() && !input.publicEmail?.trim()) {
    reasons.push("Add a public phone number or email so patients can reach you.");
  }
  if (input.activeLocationCount < 1) {
    reasons.push("Add at least one location.");
  }

  return { ready: reasons.length === 0, reasons };
}
