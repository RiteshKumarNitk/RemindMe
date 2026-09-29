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
        // Primary-location address capture (request §12): the ClinicLocation
        // model has always had these columns; collecting them at creation
        // gives public discovery a real address from day one.
        addressLine1: z.string().max(200).optional(),
        state: z.string().max(120).optional(),
        postalCode: z.string().max(20).optional(),
      })
      .strict()
      .optional(),
  })
  .strict();
export type CreateOrgInput = z.infer<typeof createOrgSchema>;
