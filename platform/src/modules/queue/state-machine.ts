import type { QueueState } from "@prisma/client";
import { AppError } from "@/lib/errors.js";

/**
 * Clinic queue transitions (QUEUE_MANAGEMENT.md).
 *
 * HOLD vs SKIPPED vs NO_SHOW are deliberately three different things
 * (TOKEN_BOOKING_ASSESSMENT.md §"queue states"):
 *   - SKIP    — the patient was called and missed it; RECALL brings them back
 *               into the WAITING line, still ahead of people who weren't called.
 *   - HOLD    — the patient is still here but temporarily out of the running
 *               order (e.g. stepped out, paperwork pending, went to lab). RECALL
 *               promotes a HOLD straight back to CALLED, because "recall" means
 *               "call them again", and a held patient has not already been called.
 *   - NO_SHOW — the patient never arrived / abandoned. Terminal, never recalled.
 *
 * `HOLD` records its own `heldAt` timestamp. NO_SHOW deliberately adds no new
 * timestamp column: the Appointment's `noShowMarkedAt` is the authoritative
 * "when was this patient declared absent", and QueueEntry.state + updatedAt is
 * enough to render the board. A third timestamp would duplicate an existing
 * fact (TOKEN_BOOKING_ASSESSMENT.md "minimal additive schema").
 */
export type QueueAction =
  | "CALL"
  | "RECALL"
  | "SKIP"
  | "START"
  | "COMPLETE"
  | "HOLD"
  | "RELEASE" // HOLD -> WAITING (patient stepped back in)
  | "NO_SHOW";

const TABLE: Record<QueueState, Partial<Record<QueueAction, QueueState>>> = {
  WAITING: { CALL: "CALLED", SKIP: "SKIPPED", HOLD: "HOLD", NO_SHOW: "NO_SHOW" },
  // CALLED -> HOLD is the everyday case: token called, nobody answered, park
  // them and move on without losing them (spec §8).
  CALLED: { RECALL: "WAITING", SKIP: "SKIPPED", HOLD: "HOLD", START: "IN_CONSULTATION", NO_SHOW: "NO_SHOW" },
  SKIPPED: { RECALL: "WAITING", NO_SHOW: "NO_SHOW" },
  IN_CONSULTATION: { COMPLETE: "COMPLETED" },
  COMPLETED: {},
  HOLD: { RELEASE: "WAITING", RECALL: "CALLED", NO_SHOW: "NO_SHOW" },
  NO_SHOW: {},
};

export function nextQueueState(from: QueueState, action: QueueAction): QueueState {
  const to = TABLE[from]?.[action];
  if (!to) {
    throw new AppError(
      "INVALID_QUEUE_TRANSITION",
      `Cannot ${action} a queue entry that is ${from}.`,
    );
  }
  return to;
}

/** True if `action` is legal from `from` (no throw). Drives which buttons the
 *  reception board renders, so the UI can never offer an illegal transition. */
export function canQueueTransition(from: QueueState, action: QueueAction): boolean {
  return Boolean(TABLE[from]?.[action]);
}

/** States that still occupy a place in today's running order. */
export const ACTIVE_QUEUE_STATES: QueueState[] = [
  "WAITING",
  "CALLED",
  "IN_CONSULTATION",
];

/** States that are finished for today (skipped-but-recallable, or terminal). */
export const CLOSED_QUEUE_STATES: QueueState[] = [
  "HOLD",
  "SKIPPED",
  "COMPLETED",
  "NO_SHOW",
];

/**
 * True when the queue is mid-consultation: someone is IN_CONSULTATION, or has
 * been CALLED but hasn't started yet. `callNext` must refuse in that state —
 * otherwise "call next" would silently abandon the patient already called.
 */
export function hasUnfinishedCall(entries: Array<{ state: QueueState }>): boolean {
  return entries.some((e) => e.state === "IN_CONSULTATION" || e.state === "CALLED");
}