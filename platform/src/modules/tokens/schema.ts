import { z } from "zod";
import { selfPatientDetailsSchema } from "@/modules/patient-booking/schema.js";
import { MAX_TOKEN_MINUTE, MIN_TOKEN_MINUTE } from "./window.js";

/**
 * Request shapes for same-day token booking.
 *
 * Deliberately NOT accepting a date. There is no `date` field anywhere in these
 * schemas: a token is same-day by definition, and the server derives "today"
 * from the clinic's timezone. A client that wants a token for another day cannot
 * express it, which is stronger than validating and rejecting one (schema §"same
 * day only").
 */

const minuteOfDay = z.number().int().min(MIN_TOKEN_MINUTE).max(MAX_TOKEN_MINUTE);

export const bookTokenSchema = z
  .object({
    organizationId: z.string().uuid(),
    doctorId: z.string().uuid(),
    locationId: z.string().uuid().optional(),
    reason: z.string().max(1000).optional(),
    /** Demographics, collected on first booking at a clinic — same shape as slot
     *  booking. Required for parity with `selfBookAppointmentSchema`: the field
     *  is ignored when the caller already has a Patient record. */
    patient: selfPatientDetailsSchema,
    /**
     * Book for a dependent instead of the caller. Never an authorization
     * decision by itself — the server re-checks an active MANAGE_APPOINTMENTS
     * grant before using it.
     */
    patientId: z.string().uuid().optional(),
  })
  .strict();
export type BookTokenInput = z.infer<typeof bookTokenSchema>;

/** Staff-issued walk-in. Requires a resolved patient — staff pick the record. */
export const walkInTokenSchema = z
  .object({
    patientId: z.string().uuid(),
    reason: z.string().max(1000).optional(),
    locationId: z.string().uuid().optional(),
  })
  .strict();
export type WalkInTokenInput = z.infer<typeof walkInTokenSchema>;

/**
 * Per-doctor booking preferences. A doctor may set their own; a clinic admin may
 * set anyone's (enforced by `updateDoctor`, not here — this is only shape).
 *
 * Every field is optional so the profile PATCH stays a partial update. The
 * window is only validated as a whole when one of its members changes, so
 * saving just `bio` can't fail on someone else's stale window config.
 */
export const bookingPreferenceSchema = z
  .object({
    bookingMode: z.enum(["SCHEDULED", "SAME_DAY_TOKEN", "BOTH"]).optional(),
    tokenOpensMinute: minuteOfDay.optional(),
    tokenClosesMinute: minuteOfDay.optional(),
    queueStartMinute: minuteOfDay.optional(),
    maxDailyTokens: z.number().int().min(1).max(1000).optional(),
  })
  .strict();
export type BookingPreferenceInput = z.infer<typeof bookingPreferenceSchema>;

export const tokenWindowQuerySchema = z
  .object({
    doctorId: z.string().uuid(),
    date: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
  })
  .strict();