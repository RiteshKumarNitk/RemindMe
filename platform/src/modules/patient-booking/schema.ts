import { z } from "zod";

/**
 * A patient's own demographic details, collected the first time they book
 * with a given clinic (Patient rows are org-scoped — see DATABASE_DESIGN.md
 * / patients/schema.ts's "self-signup linking" note). Deliberately the same
 * shape as `createPatientSchema` minus staff-only fields (mrn, notes,
 * ownerEmail — the caller already IS the owner here).
 */
export const selfPatientDetailsSchema = z
  .object({
    firstName: z.string().min(1).max(120),
    lastName: z.string().min(1).max(120),
    phone: z.string().max(40).optional(),
    dateOfBirth: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/)
      .optional(),
    sex: z.string().max(20).optional(),
  })
  .strict();

export const selfBookAppointmentSchema = z
  .object({
    organizationId: z.string().uuid(),
    doctorId: z.string().uuid(),
    scheduledStart: z.string().datetime(),
    appointmentTypeId: z.string().uuid().optional(),
    locationId: z.string().uuid().optional(),
    reason: z.string().max(1000).optional(),
    patient: selfPatientDetailsSchema,
    // Book for a dependent instead of the caller themself — only honored if
    // the caller actually holds a MANAGE_APPOINTMENTS grant on this patient
    // (re-checked server-side inside the booking transaction; this being
    // present is never itself an authorization decision).
    patientId: z.string().uuid().optional(),
  })
  .strict();
export type SelfBookAppointmentInput = z.infer<typeof selfBookAppointmentSchema>;

export const publicSlotsQuerySchema = z
  .object({
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    appointmentTypeId: z.string().uuid().optional(),
  })
  .strict();
