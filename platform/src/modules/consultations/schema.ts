import { z } from "zod";

export const saveConsultationSchema = z
  .object({
    subjective: z.string().max(5000).optional(),
    objective: z.string().max(5000).optional(),
    assessment: z.string().max(5000).optional(),
    plan: z.string().max(5000).optional(),
    followUpDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    testsAdvised: z.string().max(2000).optional(),
    instructions: z.string().max(2000).optional(),
  })
  .strict();
export type SaveConsultationInput = z.infer<typeof saveConsultationSchema>;
