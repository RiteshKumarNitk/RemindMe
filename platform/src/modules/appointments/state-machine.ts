import type { AppointmentStatus } from "@prisma/client";
import { AppError } from "@/lib/errors.js";

/**
 * Appointment lifecycle (APPOINTMENT_WORKFLOW.md). Only the transitions listed
 * here are legal; anything else → 409 INVALID_STATUS_TRANSITION. Arbitrary
 * `PATCH status` is never allowed — callers use the named action functions.
 */
export type AppointmentAction =
  | "CONFIRM"
  | "CANCEL"
  | "RESCHEDULE"
  | "CHECK_IN"
  | "NO_SHOW"
  | "START"
  | "COMPLETE"
  | "ENQUEUE"; // system: CHECKED_IN -> WAITING when the QueueEntry is created

const TABLE: Record<AppointmentStatus, Partial<Record<AppointmentAction, AppointmentStatus>>> = {
  REQUESTED: {
    CONFIRM: "CONFIRMED",
    CANCEL: "CANCELLED",
    RESCHEDULE: "RESCHEDULED",
  },
  CONFIRMED: {
    CHECK_IN: "CHECKED_IN",
    CANCEL: "CANCELLED",
    RESCHEDULE: "RESCHEDULED",
    NO_SHOW: "NO_SHOW",
  },
  CHECKED_IN: {
    ENQUEUE: "WAITING",
    START: "IN_CONSULTATION",
    CANCEL: "CANCELLED",
  },
  WAITING: {
    START: "IN_CONSULTATION",
    CANCEL: "CANCELLED",
  },
  IN_CONSULTATION: {
    COMPLETE: "COMPLETED",
  },
  COMPLETED: {},
  CANCELLED: {},
  NO_SHOW: {},
  RESCHEDULED: {},
};

export const TERMINAL: AppointmentStatus[] = [
  "COMPLETED",
  "CANCELLED",
  "NO_SHOW",
  "RESCHEDULED",
];

export function nextStatus(
  from: AppointmentStatus,
  action: AppointmentAction,
): AppointmentStatus {
  const to = TABLE[from]?.[action];
  if (!to) {
    throw new AppError(
      "INVALID_STATUS_TRANSITION",
      `Cannot ${action} an appointment that is ${from}.`,
    );
  }
  return to;
}

/** True if `action` is legal from `from` (no throw). */
export function canTransition(from: AppointmentStatus, action: AppointmentAction): boolean {
  return Boolean(TABLE[from]?.[action]);
}
