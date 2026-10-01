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
  if (!(err instanceof Prisma.PrismaClientKnownRequestError)) return false;
  if (err.code === "P2034" || err.code === "P2037") return true;
  // A serialization failure raised inside a RAW statement (e.g. the token
  // allocator's INSERT … ON CONFLICT) surfaces as P2010 "raw query failed"
  // carrying the Postgres SQLSTATE, not as P2034. Without this, concurrent
  // token bookings at the opening minute returned 500 instead of retrying.
  if (err.code === "P2010") {
    const pgCode = (err.meta as { code?: unknown } | undefined)?.code;
    return pgCode === "40001" || pgCode === "40P01" || /40001|could not serialize/i.test(err.message);
  }
  return false;
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
        // Jittered backoff: a burst of identical requests (the opening-minute
        // rush) must not retry in lockstep and collide again.
        await new Promise((r) => setTimeout(r, 25 * (attempt + 1) + Math.random() * 50 * (attempt + 1)));
        continue;
      }
      throw err;
    }
  }
  throw lastErr instanceof Error
    ? new AppError("CONFLICT", "The request could not be completed. Please retry.")
    : new AppError("CONFLICT", "The request could not be completed. Please retry.");
}
