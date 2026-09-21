import { Prisma } from "@prisma/client";
import { db } from "./db.js";
import { AppError } from "./errors.js";

/** Message fragments Postgres uses for the appointment overlap EXCLUDE. */
const OVERLAP_MARKERS = [
  "Appointment_org_doctor_no_overlap",
  "exclusion",
  "23P01",
  "conflicting key value violates exclusion constraint",
];

export function isOverlapViolation(err: unknown): boolean {
  const msg = err instanceof Error ? err.message : String(err);
  return OVERLAP_MARKERS.some((m) => msg.toLowerCase().includes(m.toLowerCase()));
}

function isWriteConflict(err: unknown): boolean {
  return (
    err instanceof Prisma.PrismaClientKnownRequestError &&
    (err.code === "P2034" || err.code === "P2037")
  );
}

/**
 * Run `fn` in a SERIALIZABLE transaction, retrying a few times on a write
 * conflict (APPOINTMENT_WORKFLOW.md booking algorithm). An overlap-constraint
 * violation is mapped to 409 APPOINTMENT_SLOT_TAKEN — never retried.
 */
export async function runSerializable<T>(
  fn: (tx: Prisma.TransactionClient) => Promise<T>,
  retries = 3,
): Promise<T> {
  let lastErr: unknown;
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await db.$transaction(fn, {
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      });
    } catch (err) {
      if (isOverlapViolation(err)) {
        throw new AppError(
          "APPOINTMENT_SLOT_TAKEN",
          "That slot is no longer available.",
        );
      }
      if (isWriteConflict(err) && attempt < retries) {
        lastErr = err;
        await new Promise((r) => setTimeout(r, 25 * (attempt + 1)));
        continue;
      }
      throw err;
    }
  }
  throw lastErr instanceof Error
    ? new AppError("CONFLICT", "The request could not be completed. Please retry.")
    : new AppError("CONFLICT", "The request could not be completed. Please retry.");
}
