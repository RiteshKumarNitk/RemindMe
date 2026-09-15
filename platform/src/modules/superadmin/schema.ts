import { z } from "zod";

export const listOrganizationsQuerySchema = z
  .object({
    q: z.string().max(200).optional(),
    status: z.enum(["all", "active", "suspended"]).default("all"),
    limit: z.coerce.number().int().min(1).max(200).default(50),
  })
  .strict();
export type ListOrganizationsQuery = z.infer<typeof listOrganizationsQuerySchema>;

export const setOrganizationActiveSchema = z
  .object({
    isActive: z.boolean(),
  })
  .strict();

export const listPlatformAuditQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(200).default(100),
  })
  .strict();
