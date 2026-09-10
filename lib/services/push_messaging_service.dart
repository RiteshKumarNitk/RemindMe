import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/notifications/notification_service.dart';
import '../data/database/app_database.dart';
import '../data/models/dose_status.dart';
import '../data/repositories/dose_repository.dart';
import '../data/repositories/medicine_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/sync_repository.dart';
import '../core/notifications/reminder_text.dart';

/// Handles FCM `medicine_reminder` messages from the server-side
/// [sendScheduledReminders] Cloud Function.
///
/// Relationship to the local alarm:
///   - The on-device AlarmManager alarm ([NotificationService.scheduleDoseReminder])
///     is the PRIMARY reminder and works offline / when the app is closed.
///   - This FCM path is a cloud BACKUP for cases where the local alarm was
///     dropped (aggressive OEM kill, not reopened since reboot, …).
///   - Both post the notification with id == doseId, so Android shows only
///     one; whichever lands second just updates it in place. That is the
///     dedup (Part 11) — no timestamp guessing.
///   - Before showing anything we re-check the local DB: a dose already
///     taken / skipped / missed produces no notification.
class PushMessagingService {
  PushMessagingService(this._notifications);

  final NotificationService _notifications;

  /// Foreground + tap wiring. Call after Firebase + NotificationService init.
  Future<void> init({
    required Future<void> Function(String? actionId, String? payload) onTap,
  }) async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    FirebaseMessaging.onMessage.listen((msg) async {
      if (msg.data['type'] != 'medicine_reminder') return;
      await _showIfDue(_notifications, msg.data);
    });

    // App opened by tapping the FCM notification.
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      final doseId = msg.data['doseId'];
      if (doseId != null) {
        onTap(null, '${AppConstants.payloadPrefix}$doseId');
      }
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null && initial.data['doseId'] != null) {
      await onTap(
        null,
        '${AppConstants.payloadPrefix}${initial.data['doseId']}',
      );
    }
  }
}

/// Shows a reminder for [data] only if that dose is still pending locally.
/// Posts with id == doseId so it collapses with any local-alarm notification.
Future<void> _showIfDue(
  NotificationService notifications,
  Map<String, dynamic> data,
) async {
  final doseId = int.tryParse('${data['doseId']}');
  if (doseId == null) return;

  final db = AppDatabase();
  final sync = SyncRepository(db);
  final doseRepo = DoseRepository(db, sync: sync);
  final medRepo = MedicineRepository(db, sync: sync);

  final dose = await doseRepo.getDose(doseId);
  if (dose == null || dose.status != DoseStatus.pending) {
    developer.log(
      'DOSE_FIRE source=fcm doseId=$doseId result=suppressed '
      'reason=${dose == null ? 'unknown-dose' : 'already-${dose.status.name}'}',
      name: 'DoseAudit',
    );
    return;
  }
  final med = await medRepo.getById(dose.medicineId);

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsRepository(prefs).load();
  final text = ReminderText.from(settings.locale,
      snoozeMinutes: settings.snoozeMinutes);
  final name = med?.name ?? 'your medicine';
  final info = med == null
      ? ''
      : text.info(med.doseLabel, med.foodInstruction,
          dose.snoozedUntil ?? dose.scheduledAt);

  developer.log(
    'DOSE_FIRE source=fcm doseId=$doseId result=notification_displayed',
    name: 'DoseAudit',
  );
  await notifications.showDoseNow(
    doseId: doseId,
    title: text.title(name),
    body: text.body(name, info),
    takenLabel: text.takenLabel,
    snoozeLabel: text.snoozeLabel,
    skipLabel: text.skipLabel,
  );
}

/// Background isolate entry point for FCM data messages while the app is
/// terminated / backgrounded. Rebuilds only what it needs (mirrors
/// notificationBackgroundHandler).
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  if (message.data['type'] != 'medicine_reminder') return;
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    await NotificationService.initTimeZone();
    final notifications = NotificationService();
    await notifications.initMinimal(soundEnabled: true);
    await _showIfDue(notifications, message.data);
  } catch (e, st) {
    developer.log('FCM background handler FAILED: $e\n$st',
        name: 'DoseAudit', error: e, stackTrace: st);
  }
}
