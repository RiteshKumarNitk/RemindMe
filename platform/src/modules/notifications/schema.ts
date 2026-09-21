import { z } from "zod";

export const listNotificationsQuerySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(50).default(20),
  })
  .strict();

export const markNotificationsReadSchema = z
  .object({
    // Omitted => mark every unread IN_APP notification for this user as read.
    ids: z.array(z.string().uuid()).max(50).optional(),
  })
  .strict();
