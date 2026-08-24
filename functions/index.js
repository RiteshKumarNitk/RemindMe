/**
 * Medicine Reminder — caregiver push alerts.
 *
 * When a dose in a household is marked `missed` (the primary phone does this
 * automatically after the grace period), every member with an FCM token gets
 * a push notification.
 *
 * Deploy:
 *   cd functions && npm install && firebase deploy --only functions
 */
const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const ALERT_TTL_MS = 24 * 60 * 60 * 1000; // don't notify for ancient history

exports.onDoseWrite = functions.firestore
  .document('households/{code}/doses/{doseId}')
  .onWrite(async (change, context) => {
    const before = change.before && change.before.data();
    const after = change.after && change.after.data();

    // Only act when a dose *becomes* missed.
    if (!after || after.status !== 'missed') return;
    if (before && before.status === 'missed') return;

    const scheduledAt = Date.parse(after.scheduled_at || after.scheduledAt);
    if (!scheduledAt || Date.now() - scheduledAt > ALERT_TTL_MS) return;

    const { code } = context.params;
    const name = after.medicine_name || 'Medicine';
    const time = after.scheduled_at || after.scheduledAt || '';

    const household = await admin
      .firestore()
      .collection('households')
      .doc(code)
      .get();
    const members = (household.data() && household.data().members) || {};

    const tokens = Object.values(members)
      .map((m) => m && m.fcmToken)
      .filter((t) => typeof t === 'string' && t.length > 0);

    if (tokens.length === 0) return;

    const payload = {
      notification: {
        title: '⚠️ Missed medicine',
        body: `${name} at ${time} was not taken`,
      },
      android: {
        priority: 'high',
        notification: { channel_id: 'family_alerts' },
      },
    };

    await admin.messaging().sendEachForMulticast({
      tokens,
      ...payload,
    });
  });
