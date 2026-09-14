import { z } from "zod";

export const bookSchema = z
  .object({
    patientId: z.string().uuid(),
    doctorId: z.string().uuid(),
    scheduledStart: z.string().datetime(),
    appointmentTypeId: z.string().uuid().optional(),
    locationId: z.string().uuid().optional(),
    reason: z.string().max(1000).optional(),
    notes: z.string().max(2000).optional(),
  })
  .strict();
export type BookInput = z.infer<typeof bookSchema>;

export const listQuerySchema = z
  .object({
    from: z.string().datetime().optional(),
    to: z.string().datetime().optional(),
    doctorId: z.string().uuid().optional(),
    patientId: z.string().uuid().optional(),
    status: z
      .enum([
        "REQUESTED",
        "CONFIRMED",
        "CHECKED_IN",
        "WAITING",
        "IN_CONSULTATION",
        "COMPLETED",
        "CANCELLED",
        "NO_SHOW",
        "RESCHEDULED",
      ])
      .optional(),
    limit: z.coerce.number().int().min(1).max(100).default(25),
  })
  .strict();

export const cancelSchema = z
  .object({ reason: z.string().min(1).max(1000) })
  .strict();

export const rescheduleSchema = z
  .object({
    scheduledStart: z.string().datetime(),
    appointmentTypeId: z.string().uuid().optional(),
    reason: z.string().max(1000).optional(),
  })
  .strict();

export const createTypeSchema = z
  .object({
    name: z.string().min(1).max(120),
    durationMinutes: z.number().int().min(5).max(240),
    colorHex: z
      .string()
      .regex(/^#[0-9a-fA-F]{6}$/)
      .optional(),
  })
  .strict();
