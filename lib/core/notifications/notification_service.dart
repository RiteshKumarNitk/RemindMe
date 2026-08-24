import 'dart:ui';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../constants/app_constants.dart';

/// Interface for scheduling/cancelling dose reminders so the scheduler can be
/// tested with a fake.
abstract class ReminderScheduler {
  Future<bool> scheduleDoseReminder({
    required int doseId,
    required String title,
    required String body,
    required DateTime when,
    required bool exact,
    required String takenLabel,
    required String snoozeLabel,
    required String skipLabel,
  });

  Future<void> cancel(int id);

  /// Ids of all scheduled (not yet shown) notifications.
  Future<Set<int>> pendingIds();
}

/// Wraps flutter_local_notifications. All reminder delivery goes through this
/// service: exact alarms when permitted, inexact as a graceful fallback.
///
/// Important for elderly users:
/// - Custom loud vibration pattern (double vibrate)
/// - LED lights enabled
/// - Foreground notifications displayed
/// - Alarm-level importance on all channels
class NotificationService implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _soundEnabled = true;

  bool get initialized => _initialized;

  /// Custom vibration pattern: two short buzzes, pause, then long buzz.
  /// Designed to be noticeable for elderly users who may not feel a single
  /// vibration through clothing or while resting.
  static final Int64List _vibrationPattern = Int64List.fromList(<int>[
    0, 300, 200, // buzz, pause, buzz
    500, // long pause
    400, 200, 400, // buzz, pause, buzz
  ]);



  /// Initializes the plugin, creates channels and registers the callback for
  /// notification taps / action buttons.
  Future<void> init({
    required bool soundEnabled,
    required void Function(NotificationResponse response) onResponse,
  }) async {
    try {
      _soundEnabled = soundEnabled;
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: onResponse,
      );
      await _createChannels();
      _initialized = true;
    } catch (_) {
      // Unsupported platform (e.g. web): notifications are unavailable but
      // the app keeps running — scheduling methods no-op via _initialized.
      _initialized = false;
    }
  }

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.channelId,
        AppConstants.channelName,
        description: AppConstants.channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('medicine_alarm'),
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF2E7D32),
        vibrationPattern: _vibrationPattern,
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.silentChannelId,
        AppConstants.silentChannelName,
        description: AppConstants.channelDescription,
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF2E7D32),
        vibrationPattern: _vibrationPattern,
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.familyChannelId,
        AppConstants.familyChannelName,
        description: AppConstants.channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('medicine_alarm'),
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFE65100),
        vibrationPattern: _vibrationPattern,
      ),
    );
  }

  /// Re-creates channels after a sound setting change. Existing pending
  /// notifications keep their old channel until rescheduled (call
  /// [cancelAllPending] + re-sync afterwards).
  Future<void> applySoundSetting(bool soundEnabled) async {
    _soundEnabled = soundEnabled;
    await _createChannels();
  }

  /// Shows an immediate (non-scheduled) alert, e.g. a missed-dose notice for
  /// a family watcher.
  Future<void> showMissedAlert({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: _alertCounter++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.familyChannelId,
            AppConstants.familyChannelName,
            channelDescription: AppConstants.channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound(
              'medicine_alarm',
            ),
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Shows an immediate refill reminder when a medicine is running low.
  Future<void> showRefillAlert({
    required String title,
    required String body,
  }) async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        id: _alertCounter++,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.familyChannelId,
            AppConstants.familyChannelName,
            channelDescription: AppConstants.channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound(
              'medicine_alarm',
            ),
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
          ),
        ),
      );
    } catch (_) {}
  }

  static int _alertCounter = 100000;

  bool get soundEnabled => _soundEnabled;

  // ---- Permissions ---------------------------------------------------------

  /// Returns whether notifications are enabled.
  /// IMPORTANT: This does NOT request permission — it only checks.
  Future<bool> areNotificationsEnabled() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.areNotificationsEnabled() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Asks the OS for notification permission. Shows the system dialog on
  /// Android 13+; on older versions this is auto-granted at install.
  /// Returns true if permission is now granted.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission() ?? false;
      return granted;
    } catch (_) {
      return true;
    }
  }

  /// Opens Android notification settings so the user can toggle them.
  Future<void> openNotificationSettings() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        await android.requestNotificationsPermission();
      }
    } catch (_) {}
  }

  Future<bool> canScheduleExact() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system screen to grant exact-alarm access. Returns whether
  /// permission is available afterwards.
  Future<bool> requestExactAlarmPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      await android.requestExactAlarmsPermission();
    } catch (_) {
      // Fall through; canScheduleExact below reports the real state.
    }
    return canScheduleExact();
  }

  // ---- Scheduling ----------------------------------------------------------

  @override
  Future<bool> scheduleDoseReminder({
    required int doseId,
    required String title,
    required String body,
    required DateTime when,
    required bool exact,
    required String takenLabel,
    required String snoozeLabel,
    required String skipLabel,
  }) async {
    if (!_initialized) return false;
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    if (!tzWhen.isAfter(tz.TZDateTime.now(tz.local))) return false;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _soundEnabled ? AppConstants.channelId : AppConstants.silentChannelId,
        _soundEnabled
            ? AppConstants.channelName
            : AppConstants.silentChannelName,
        channelDescription: AppConstants.channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        playSound: _soundEnabled,
        sound: _soundEnabled
            ? const RawResourceAndroidNotificationSound('medicine_alarm')
            : null,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFF2E7D32),
        ledOnMs: 1000,
        ledOffMs: 500,
        vibrationPattern: _vibrationPattern,
        // fullScreenIntent makes the notification behave like an alarm —
        // it shows a full-screen UI even when the device is locked.
        // Critical for elderly users who may not notice a status-bar icon.
        fullScreenIntent: true,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: AppConstants.channelName,
        ),
        actions: [
          AndroidNotificationAction(
            AppConstants.actionTaken,
            takenLabel,
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            AppConstants.actionSnooze,
            snoozeLabel,
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            AppConstants.actionSkip,
            skipLabel,
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      ),
    );
    final payload = '${AppConstants.payloadPrefix}$doseId';

    try {
      await _plugin.zonedSchedule(
        id: doseId,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
      return true;
    } on Exception {
      // Exact alarm permission missing/revoked: fall back to inexact so the
      // reminder still arrives (just not guaranteed to the minute).
      try {
        await _plugin.zonedSchedule(
          id: doseId,
          title: title,
          body: body,
          scheduledDate: tzWhen,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        return true;
      } on Exception {
        return false;
      }
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  @override
  Future<Set<int>> pendingIds() async {
    if (!_initialized) return {};
    try {
      final requests = await _plugin.pendingNotificationRequests();
      return requests.map((r) => r.id).toSet();
    } catch (_) {
      return {};
    }
  }

  /// Dismisses every scheduled (not yet shown) reminder. Shown notifications
  /// are left alone so the user can still act on them.
  Future<void> cancelAllPending() async {
    if (!_initialized) return;
    try {
      final requests = await _plugin.pendingNotificationRequests();
      for (final r in requests) {
        await _plugin.cancel(id: r.id);
      }
    } catch (_) {}
  }

  /// Whether the app was launched by tapping a notification (or its action).
  Future<NotificationAppLaunchDetails?> getLaunchDetails() async {
    try {
      return await _plugin.getNotificationAppLaunchDetails();
    } catch (_) {
      return null;
    }
  }

  // ---- Time zone -----------------------------------------------------------

  static Future<void> initTimeZone() async {
    tzdata.initializeTimeZones();
    String name;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      name = info.identifier;
    } catch (_) {
      name = 'UTC';
    }
    try {
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {
      // Keep the default location when the name is unknown.
    }
  }
}
