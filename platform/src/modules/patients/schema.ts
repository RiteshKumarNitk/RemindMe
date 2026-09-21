import { z } from "zod";

export const createPatientSchema = z
  .object({
    firstName: z.string().min(1).max(120),
    lastName: z.string().min(1).max(120),
    phone: z.string().max(40).optional(),
    email: z.string().email().max(320).optional(),
    dateOfBirth: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    sex: z.string().max(20).optional(),
    mrn: z.string().max(60).optional(),
    notes: z.string().max(2000).optional(),
    // Links this record to an existing platform account (a PATIENT-role
    // member) so that user's web/app dashboard shows it. Silently ignored
    // if no such account exists yet — self-signup linking is Phase 3.
    ownerEmail: z.string().email().max(320).optional(),
  })
  .strict();
export type CreatePatientInput = z.infer<typeof createPatientSchema>;

export const listPatientsQuerySchema = z
  .object({
    q: z.string().max(200).optional(), // search: name / phone / mrn
    limit: z.coerce.number().int().min(1).max(100).default(25),
  })
  .strict();
