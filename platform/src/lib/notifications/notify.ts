import type { NotificationChannel, Prisma, PrismaClient } from "@prisma/client";
import { db } from "../db.js";

type Db = PrismaClient | Prisma.TransactionClient;

export interface NotifyInput {
  organizationId?: string | null;
  userId?: string | null;
  channel?: NotificationChannel;
  event: string;
  payload: Record<string, unknown>;
  scheduledFor?: Date | null;
  /** Deterministic key → idempotent creation (reminders). Omit for one-offs. */
  dedupeKey?: string;
}

/**
 * Enqueue a notification (NOTIFICATION_ARCHITECTURE.md). Supplementary — a
 * failure here must never break the caller, so this swallows errors.
 */
export async function notify(input: NotifyInput, database: Db = db): Promise<void> {
  try {
    if (input.dedupeKey) {
      const existing = await (database as PrismaClient).notification.findUnique({
        where: { dedupeKey: input.dedupeKey },
        select: { id: true },
      });
      if (existing) return;
    }
    await (database as PrismaClient).notification.create({
      data: {
        organizationId: input.organizationId ?? null,
        userId: input.userId ?? null,
        channel: input.channel ?? "IN_APP",
        event: input.event,
        payload: input.payload as Prisma.InputJsonValue,
        scheduledFor: input.scheduledFor ?? null,
        dedupeKey: input.dedupeKey ?? null,
        maxAttempts: 5,
      },
    });
  } catch {
    // best-effort
  }
}
