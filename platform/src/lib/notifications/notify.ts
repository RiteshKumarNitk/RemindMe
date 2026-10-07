import type { NotificationChannel, Prisma, PrismaClient } from "@prisma/client";
import { db } from "../db.js";
import { fcmConfigured, sendPushToUser } from "./fcm.js";
import { pushCopy } from "./push-copy.js";

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
 *
 * Immediate notifications (no `scheduledFor`) created outside a transaction
 * are also pushed to the user's phones right away and marked SENT, so the
 * dispatcher doesn't push them a second time. Anything not delivered here
 * stays PENDING for the dispatcher to retry.
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
    const row = await (database as PrismaClient).notification.create({
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
      select: { id: true },
    });

    // Never push from inside a caller's transaction: it may still roll back.
    if (database === db && !input.scheduledFor && input.userId && fcmConfigured()) {
      const copy = pushCopy(input.event, input.payload);
      if (!copy) return;
      const result = await sendPushToUser(input.userId, copy);
      if (result.failed === 0) {
        await db.notification.update({
          where: { id: row.id },
          data: { status: "SENT", sentAt: new Date() },
        });
      }
    }
  } catch {
    // best-effort
  }
}
