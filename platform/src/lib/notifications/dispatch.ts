import { Prisma } from "@prisma/client";
import { db } from "../db.js";
import { env } from "../env.js";

/**
 * Notification dispatcher (NOTIFICATION_ARCHITECTURE.md). Plain Postgres,
 * no Redis: `FOR UPDATE SKIP LOCKED` claiming + a stale-`SENDING` reaper for
 * crash recovery. Channel adapters are minimal in Phase 1 (IN_APP is the feed;
 * PUSH is SUPPRESSED unless FCM is configured).
 */
export interface DispatchResult {
  claimed: number;
  sent: number;
  failed: number;
  requeued: number;
  reaped: number;
}

const fcmConfigured = false; // wired in a later phase

function backoffMs(attempts: number): number {
  const table = [60_000, 300_000, 900_000, 3_600_000, 10_800_000];
  return table[Math.min(attempts - 1, table.length - 1)]!;
}

export async function runDispatch(): Promise<DispatchResult> {
  const result: DispatchResult = { claimed: 0, sent: 0, failed: 0, requeued: 0, reaped: 0 };

  // 1) Reap stragglers: SENDING rows whose claim is older than the timeout.
  const reaped = await db.notification.updateMany({
    where: {
      status: "SENDING",
      claimedAt: {
        lt: new Date(Date.now() - env.NOTIFICATIONS_CLAIM_TIMEOUT_MIN * 60_000),
      },
    },
    data: { status: "PENDING", claimedAt: null },
  });
  result.reaped = reaped.count;

  // 2) Claim a batch atomically.
  const claimedRows = await db.$queryRaw<
    Array<{ id: string; channel: string; attempts: number }>
  >(Prisma.sql`
    WITH due AS (
      SELECT "id" FROM "Notification"
      WHERE "status" = 'PENDING'
        AND ("scheduledFor" IS NULL OR "scheduledFor" <= now())
        AND ("nextAttemptAt" IS NULL OR "nextAttemptAt" <= now())
      ORDER BY "scheduledFor" NULLS FIRST
      LIMIT ${env.NOTIFICATIONS_DISPATCH_BATCH}
      FOR UPDATE SKIP LOCKED
    )
    UPDATE "Notification" n
       SET "status" = 'SENDING', "claimedAt" = now(), "attempts" = n."attempts" + 1
      FROM due
     WHERE n."id" = due."id"
    RETURNING n."id", n."channel"::text AS channel, n."attempts";
  `);
  result.claimed = claimedRows.length;

  // 3) "Send" each claimed row.
  for (const row of claimedRows) {
    try {
      let outcome: "SENT" | "SUPPRESSED";
      if (row.channel === "IN_APP") outcome = "SENT";
      else if (row.channel === "PUSH") outcome = fcmConfigured ? "SENT" : "SUPPRESSED";
      else outcome = "SUPPRESSED"; // EMAIL/SMS/WHATSAPP not in MVP

      await db.notification.update({
        where: { id: row.id },
        data: {
          status: outcome,
          sentAt: outcome === "SENT" ? new Date() : null,
          claimedAt: null,
          error: null,
        },
      });
      if (outcome === "SENT") result.sent += 1;
    } catch (err) {
      const permanent = false;
      const attempts = row.attempts;
      if (permanent || attempts >= env.NOTIFICATIONS_MAX_ATTEMPTS) {
        await db.notification.update({
          where: { id: row.id },
          data: { status: "FAILED", claimedAt: null, error: String(err).slice(0, 500) },
        });
        result.failed += 1;
      } else {
        await db.notification.update({
          where: { id: row.id },
          data: {
            status: "PENDING",
            claimedAt: null,
            nextAttemptAt: new Date(Date.now() + backoffMs(attempts)),
            error: String(err).slice(0, 500),
          },
        });
        result.requeued += 1;
      }
    }
  }

  return result;
}
