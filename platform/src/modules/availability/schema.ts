import { z } from "zod";

const ruleSchema = z
  .object({
    weekday: z.number().int().min(1).max(7), // ISO: 1 = Mon .. 7 = Sun
    startMinute: z.number().int().min(0).max(24 * 60 - 1),
    endMinute: z.number().int().min(1).max(24 * 60),
    slotMinutes: z.number().int().min(5).max(240),
    locationId: z.string().uuid().nullable().optional(),
    effectiveFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
    effectiveTo: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).nullable().optional(),
  })
  .strict()
  .refine((r) => r.endMinute > r.startMinute, {
    message: "endMinute must be after startMinute",
  });

export const putRulesSchema = z
  .object({ rules: z.array(ruleSchema).max(60) })
  .strict();
export type PutRulesInput = z.infer<typeof putRulesSchema>;

export const createExceptionSchema = z
  .object({
    kind: z.enum(["DAY_OFF", "HOLIDAY", "LEAVE", "EXTRA_HOURS", "BREAK"]),
    startsAt: z.string().datetime(),
    endsAt: z.string().datetime(),
    reason: z.string().max(500).optional(),
    locationId: z.string().uuid().nullable().optional(),
  })
  .strict()
  .refine((e) => new Date(e.endsAt) > new Date(e.startsAt), {
    message: "endsAt must be after startsAt",
  });

export const slotsQuerySchema = z
  .object({
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
    typeId: z.string().uuid().optional(),
  })
  .strict();
