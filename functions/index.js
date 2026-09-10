/**
 * DoseWise Cloud Functions
 * ========================
 *
 * TWO responsibilities, both server-side (never a client "schedule this for
 * 20:30" timer — that dies with the app process):
 *
 *   1. sendScheduledReminders  — Cloud Scheduler, every minute. Finds doses
 *      that are due right now and sends an FCM reminder to the household's
 *      devices. This is the CLOUD half of the medicine alarm; the LOCAL
 *      AlarmManager alarm on the device is the primary and works offline.
 *      Duplicates between the two are collapsed on-device by notification id
 *      (= doseId) and skipped here once `reminderSentAt` is stamped.
 *
 *   2. onDoseMissed — Firestore trigger. When a dose flips to `missed`, push
 *      a caregiver alert to every household member.
 *
 * `doses/*.scheduled_at` is stored by the app as an absolute UTC ISO-8601
 * instant (device-local time already converted), so due-time math here is
 * timezone-independent. The member's IANA `timezone` is carried only for
 * the delivery log.
 *
 * Deploy:
 *   cd functions && npm install
 *   firebase deploy --only functions,firestore:indexes
 *
 * Required Firestore composite index (also in firestore.indexes.json):
 *   collectionGroup: doses  —  status ASC, scheduled_at ASC
 */

const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");
const { logger } = require("firebase-functions/v2");

admin.initializeApp();
const db = admin.firestore();

const MISSED_ALERT_TTL_MS = 24 * 60 * 60 * 1000;

// Look-back must exceed the schedule interval so a slow/skipped run can't
// drop a minute; look-ahead is small so we don't fire early. Re-sends are
// prevented by the `reminderSentAt` stamp, so an overlap is harmless.
const LOOKBACK_MS = 3 * 60 * 1000;
const LOOKAHEAD_MS = 30 * 1000;

/**
 * FCM tokens + timezone for every member of a household (members subcollection,
 * written by the app since the QR-invitation rework).
 */
async function householdTokens(householdId) {
  const snap = await db
    .collection("households")
    .doc(householdId)
    .collection("members")
    .get();
  const tokens = [];
  let timezone = "unknown";
  snap.forEach((m) => {
    const d = m.data() || {};
    if (typeof d.fcmToken === "string" && d.fcmToken.length > 0) {
      tokens.push(d.fcmToken);
    }
    if (typeof d.timezone === "string" && d.timezone.length > 0) {
      timezone = d.timezone;
    }
  });
  return { tokens, timezone };
}

/** Drops tokens FCM reports as permanently invalid so they aren't retried. */
async function pruneDeadTokens(householdId, tokens, responses) {
  const dead = [];
  responses.forEach((r, i) => {
    const code = r.error && r.error.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token"
    ) {
      dead.push(tokens[i]);
    }
  });
  if (dead.length === 0) return;
  const members = await db
    .collection("households")
    .doc(householdId)
    .collection("members")
    .where("fcmToken", "in", dead.slice(0, 10))
    .get();
  await Promise.all(
    members.docs.map((doc) =>
      doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() })
    )
  );
}

// ---------------------------------------------------------------------------
// 1. Scheduled medicine reminders
// ---------------------------------------------------------------------------

exports.sendScheduledReminders = onSchedule(
  { schedule: "every 1 minutes", timeZone: "Etc/UTC", retryCount: 2 },
  async () => {
    const now = Date.now();
    const windowStart = new Date(now - LOOKBACK_MS).toISOString();
    const windowEnd = new Date(now + LOOKAHEAD_MS).toISOString();

    const due = await db
      .collectionGroup("doses")
      .where("status", "==", "pending")
      .where("scheduled_at", ">=", windowStart)
      .where("scheduled_at", "<=", windowEnd)
      .get();

    if (due.empty) {
      logger.info("sendScheduledReminders: nothing due", { windowEnd });
      return;
    }

    let sent = 0;
    for (const doc of due.docs) {
      const dose = doc.data();
      const householdRef = doc.ref.parent.parent;
      if (!householdRef) continue;
      const householdId = householdRef.id;
      const doseId = doc.id;

      // Idempotency (Part 11): one FCM reminder per dose. The on-device
      // local alarm is independent; both use notification id = doseId so the
      // phone shows only one.
      if (dose.reminder_sent_at) continue;
      if (dose.deleted === true) continue;

      const { tokens, timezone } = await householdTokens(householdId);
      const logRef = db.collection("fcm_delivery_log").doc();
      const base = {
        doseId,
        householdId,
        medicineId: String(dose.medicine_id ?? ""),
        scheduledAt: dose.scheduled_at,
        timezone,
        serverExecutionTime: new Date(now).toISOString(),
        tokensTargeted: tokens.length,
      };

      if (tokens.length === 0) {
        await logRef.set({ ...base, result: "no_tokens" });
        continue;
      }

      const message = {
        tokens,
        notification: {
          title: "DoseWise — Medicine Reminder",
          body: `Time to take your ${dose.medicine_name || "medicine"}.`,
        },
        data: {
          type: "medicine_reminder",
          doseId,
          medicineId: String(dose.medicine_id ?? ""),
          scheduledAt: String(dose.scheduled_at || ""),
          action: "open_dose",
        },
        android: {
          priority: "high",
          collapseKey: `dose_${doseId}`,
          notification: {
            channelId: "medicine_reminders_v10",
            tag: `dose_${doseId}`,
            notificationPriority: "PRIORITY_MAX",
            defaultSound: false,
            sound: "medicine_alarm",
          },
        },
      };

      try {
        const res = await admin.messaging().sendEachForMulticast(message);
        await doc.ref.update({
          reminder_sent_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        await logRef.set({
          ...base,
          result: res.failureCount === 0 ? "sent" : "partial",
          successCount: res.successCount,
          failureCount: res.failureCount,
          messageIds: res.responses.map((r) => r.messageId || null),
          errors: res.responses
            .filter((r) => r.error)
            .map((r) => r.error.code),
        });
        await pruneDeadTokens(householdId, tokens, res.responses);
        sent += res.successCount;
      } catch (e) {
        logger.error("FCM send failed", { doseId, error: String(e) });
        await logRef.set({ ...base, result: "send_error", error: String(e) });
      }
    }

    logger.info("sendScheduledReminders done", {
      dueCount: due.size,
      pushed: sent,
    });
  }
);

// ---------------------------------------------------------------------------
// 2. Caregiver "missed dose" alert
// ---------------------------------------------------------------------------

exports.onDoseMissed = onDocumentWritten(
  "households/{householdId}/doses/{doseId}",
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after || after.status !== "missed") return;
    if (before && before.status === "missed") return;

    const scheduledAt = Date.parse(after.scheduled_at || "");
    if (!scheduledAt || Date.now() - scheduledAt > MISSED_ALERT_TTL_MS) return;

    const { householdId } = event.params;
    const { tokens } = await householdTokens(householdId);
    if (tokens.length === 0) return;

    const name = after.medicine_name || "Medicine";
    await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "⚠️ Missed medicine",
        body: `${name} at ${after.scheduled_at || ""} was not taken`,
      },
      android: {
        priority: "high",
        notification: { channelId: "family_alerts_v10" },
      },
    });
  }
);
