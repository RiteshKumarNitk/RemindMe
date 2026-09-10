import { z } from "zod";

const slug = z
  .string()
  .min(3)
  .max(40)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, "lowercase letters, digits and hyphens only");

export const createOrgSchema = z
  .object({
    name: z.string().min(2).max(160),
    slug,
    timezone: z.string().min(1).max(64).default("Asia/Kolkata"),
    location: z
      .object({
        name: z.string().min(1).max(160),
        city: z.string().max(120).optional(),
        timezone: z.string().max(64).optional(),
      })
      .strict()
      .optional(),
  })
  .strict();
export type CreateOrgInput = z.infer<typeof createOrgSchema>;
