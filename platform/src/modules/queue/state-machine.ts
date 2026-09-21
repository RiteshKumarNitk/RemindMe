import type { QueueState } from "@prisma/client";
import { AppError } from "@/lib/errors.js";

/** Clinic queue transitions (QUEUE_MANAGEMENT.md). */
export type QueueAction = "CALL" | "RECALL" | "SKIP" | "START" | "COMPLETE";

const TABLE: Record<QueueState, Partial<Record<QueueAction, QueueState>>> = {
  WAITING: { CALL: "CALLED", SKIP: "SKIPPED" },
  CALLED: { RECALL: "WAITING", SKIP: "SKIPPED", START: "IN_CONSULTATION" },
  SKIPPED: { RECALL: "WAITING" },
  IN_CONSULTATION: { COMPLETE: "COMPLETED" },
  COMPLETED: {},
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
