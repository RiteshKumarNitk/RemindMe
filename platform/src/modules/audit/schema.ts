import { z } from "zod";

export const listAuditQuerySchema = z
  .object({
    entityType: z.string().max(60).optional(),
    entityId: z.string().max(80).optional(),
    limit: z.coerce.number().int().min(1).max(200).default(50),
  })
  .strict();
