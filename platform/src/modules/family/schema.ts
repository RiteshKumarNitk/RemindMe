import { z } from "zod";

const RELATIONS = [
  "SELF",
  "SPOUSE",
  "FATHER",
  "MOTHER",
  "CHILD",
  "GUARDIAN",
  "OTHER",
] as const;

const PERMISSIONS = [
  "VIEW_PROFILE",
  "VIEW_APPOINTMENTS",
  "MANAGE_APPOINTMENTS",
  "VIEW_MEDICATIONS",
  "MANAGE_MEDICATIONS",
  "VIEW_DOCUMENTS",
] as const;

export const createAccessGrantSchema = z
  .object({
    granteeEmail: z.string().email().max(320),
    permissions: z.array(z.enum(PERMISSIONS)).min(1),
    relation: z.enum(RELATIONS).optional(),
    expiresAt: z.string().datetime().optional(),
  })
  .strict();
export type CreateAccessGrantInput = z.infer<typeof createAccessGrantSchema>;
