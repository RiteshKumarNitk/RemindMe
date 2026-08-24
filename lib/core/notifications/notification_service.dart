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
class NotificationService implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _soundEnabled = true;

  bool get initialized => _initialized;

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
        enableVibration: true,
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
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        AppConstants.familyChannelId,
        AppConstants.familyChannelName,
        description: AppConstants.channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
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
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.familyChannelId,
            AppConstants.familyChannelName,
            channelDescription: AppConstants.channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            playSound: true,
            enableVibration: true,
          ),
        ),
      );
    } catch (_) {}
  }

  static int _alertCounter = 100000;

  bool get soundEnabled => _soundEnabled;

  // ---- Permissions ---------------------------------------------------------

  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.requestNotificationsPermission() ?? false;
    } catch (_) {
      return true;
    }
  }

  /// True when notifications are currently enabled (no dialog shown).
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
        enableVibration: true,
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
