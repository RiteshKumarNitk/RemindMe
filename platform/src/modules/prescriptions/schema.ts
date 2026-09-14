import { z } from "zod";

export const addItemSchema = z
  .object({
    drugName: z.string().min(1).max(200),
    strength: z.string().max(60).optional(),
    form: z.string().max(60).optional(),
    dosage: z.string().max(120).optional(),
    frequency: z.string().max(120).optional(),
    durationDays: z.coerce.number().int().min(1).max(365).optional(),
    foodInstruction: z.enum(["NONE", "BEFORE", "AFTER", "WITH_FOOD"]).default("NONE"),
    instructions: z.string().max(500).optional(),
  })
  .strict();
export type AddItemInput = z.infer<typeof addItemSchema>;
