import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_background.dart';
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

  /// Cancels multiple notifications by their ids.
  Future<void> cancelAll(List<int> ids);

  /// Schedules an advance alarm notification (loops before dose time).
  Future<bool> scheduleAdvanceAlarm({
    required int doseId,
    required int offset,
    required String title,
    required String body,
    required DateTime when,
    required bool exact,
  });

  /// Ids of all scheduled (not yet shown) notifications.
  Future<Set<int>> pendingIds();
}

/// Wraps flutter_local_notifications. All reminder delivery goes through this
/// service.
///
/// Sound strategy — belt-and-suspenders for elderly users:
/// 1. Channel: bundled WAV alarm sound via RawResourceAndroidNotificationSound
/// 2. Notification details: ALSO set WAV sound (some OEMs need both)
/// 3. Double-buzz vibration pattern (noticeable through clothing)
/// 4. LED lights + fullScreenIntent (lock-screen alarm)
class NotificationService implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _soundEnabled = true;

  /// Set to false the first time `exactAllowWhileIdle` scheduling is rejected,
  /// so we don't pay 2 extra failed platform round-trips for every remaining
  /// dose in the same reconcile (this was the cause of the splash-screen hang).
  bool _exactModeUsable = true;

  bool get initialized => _initialized;

  /// ~6 seconds of insistent buzzing so an elderly user notices even with the
  /// phone in a pocket. Format: [wait, vibrate, wait, vibrate, ...] in ms.
  static final Int64List _vibrationPattern = Int64List.fromList(<int>[
    0, 600, 300, 600, 300, 600, // three strong buzzes
    500, // pause
    400, 250, 400, 250, 400, 250, 400, // rapid burst
    500,
    800, 300, 800, // two long buzzes
  ]);

  /// Android notification flag FLAG_INSISTENT (0x00000004): loops the
  /// notification sound until the notification is dismissed or actioned.
  /// Makes a dose reminder behave like an alarm instead of a 3-second chime.
  static final Int32List _insistentFlag = Int32List.fromList(<int>[4]);

  /// Version suffix for channel IDs. Bump when changing channel settings —
  /// Android caches channel config after first creation, so a new sound /
  /// importance / audio stream only takes effect on a channel ID it has
  /// never seen. v9: re-add ALARM audio attributes on the channel so the
  /// bundled WAV plays on the alarm stream (louder, bypasses Doze, and
  /// works even when notification volume is down). The belt-and-suspenders
  /// approach — sound on BOTH channel AND notification details — ensures
  /// maximum device compatibility.
  static const String _v = 'v9';

  // ---- Channel IDs (versioned) --------------------------------------------

  String get _soundChannelId => '${AppConstants.channelId}_$_v';
  String get _silentChannelId => '${AppConstants.silentChannelId}_$_v';
  String get _familyChannelId => '${AppConstants.familyChannelId}_$_v';

  /// The bundled alarm WAV file in res/raw/. This is the most reliable sound
  /// source — it ships with the app and works on every Android device.
  static const AndroidNotificationSound _alarmSound =
      RawResourceAndroidNotificationSound('medicine_alarm');

  /// Initializes the plugin, creates channels and registers the callback for
  /// notification taps / action buttons.
  Future<void> init({
    required bool soundEnabled,
    required void Function(NotificationResponse response) onResponse,
  }) async {
    try {
      _soundEnabled = soundEnabled;
      _exactModeUsable = true; // re-test exact scheduling each app run
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: onResponse,
        // Handles TAKEN / SNOOZE / SKIP action buttons when the app is in the
        // background or terminated (runs in its own isolate).
        onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
      );
      await _createChannels();
      _initialized = true;
      developer.log('NotificationService initialized OK', name: 'Notif');
    } catch (e, st) {
      _initialized = false;
      developer.log('NotificationService init FAILED: $e\n$st',
          name: 'Notif', error: e, stackTrace: st);
    }
  }

  /// Lightweight init for the background isolate: brings the plugin up so
  /// scheduling / cancelling works, but skips channel (re)creation — the
  /// channels were already created by the foreground app and persist.
  Future<void> initMinimal({required bool soundEnabled}) async {
    try {
      _soundEnabled = soundEnabled;
      const androidInit =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      _initialized = false;
      developer.log('initMinimal FAILED: $e', name: 'Notif', error: e);
    }
  }

  Future<void> _createChannels() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;

    // Delete ALL old channels so Android recreates them fresh.
    // Android ignores channel config changes after first creation — only
    // delete + recreate forces a fresh config.
    for (final oldId in [
      AppConstants.channelId,
      AppConstants.silentChannelId,
      AppConstants.familyChannelId,
      '${AppConstants.channelId}_v2',
      '${AppConstants.silentChannelId}_v2',
      '${AppConstants.familyChannelId}_v2',
      '${AppConstants.channelId}_v3',
      '${AppConstants.silentChannelId}_v3',
      '${AppConstants.familyChannelId}_v3',
      '${AppConstants.channelId}_v4',
      '${AppConstants.silentChannelId}_v4',
      '${AppConstants.familyChannelId}_v4',
      '${AppConstants.channelId}_v5',
      '${AppConstants.silentChannelId}_v5',
      '${AppConstants.familyChannelId}_v5',
      '${AppConstants.channelId}_v6',
      '${AppConstants.silentChannelId}_v6',
      '${AppConstants.familyChannelId}_v6',
      '${AppConstants.channelId}_v7',
      '${AppConstants.silentChannelId}_v7',
      '${AppConstants.familyChannelId}_v7',
      '${AppConstants.channelId}_v8',
      '${AppConstants.silentChannelId}_v8',
      '${AppConstants.familyChannelId}_v8',
      _soundChannelId,
      _silentChannelId,
      _familyChannelId,
    ]) {
      try {
        await android.deleteNotificationChannel(channelId: oldId);
      } catch (_) {}
    }

    // Sound channel: MAX importance + bundled WAV on the ALARM audio
    // stream. This ensures the sound plays even when the notification
    // volume is down or the phone is in Doze. FLAG_INSISTENT (set
    // per-notification) still loops the tone so it behaves like an alarm.
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _soundChannelId,
        AppConstants.channelName,
        description: AppConstants.channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: _alarmSound,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        enableLights: true,
        ledColor: const Color(0xFF2E7D32),
        bypassDnd: true,
      ),
    );

    // Silent channel: no sound, vibration only.
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _silentChannelId,
        AppConstants.silentChannelName,
        description: AppConstants.channelDescription,
        importance: Importance.max,
        playSound: false,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        enableLights: true,
        ledColor: const Color(0xFF2E7D32),
      ),
    );

    // Family alerts channel — same delivery, orange LED, bypass DND.
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _familyChannelId,
        AppConstants.familyChannelName,
        description: AppConstants.channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: _alarmSound,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        enableLights: true,
        ledColor: const Color(0xFFE65100),
        bypassDnd: true,
      ),
    );

    developer.log('Notification channels created (version $_v)',
        name: 'Notif');
  }

  /// Re-creates channels after a sound setting change.
  Future<void> applySoundSetting(bool soundEnabled) async {
    _soundEnabled = soundEnabled;
    await _createChannels();
  }

  /// Diagnostic: reports the current notification health state so the test
  /// button can display actionable information to the user.
  Future<Map<String, dynamic>> getHealthCheck() async {
    final result = <String, dynamic>{
      'initialized': _initialized,
      'soundEnabled': _soundEnabled,
      'channelVersion': _v,
    };
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        result['notificationsEnabled'] =
            await android.areNotificationsEnabled() ?? false;
        result['exactAlarms'] =
            await android.canScheduleExactNotifications() ?? false;
      }
    } catch (e) {
      result['healthError'] = e.toString();
    }
    final pending = await pendingIds();
    result['pendingCount'] = pending.length;
    return result;
  }

  // ---- Immediate alerts ---------------------------------------------------

  /// Shows an immediate notification (missed dose for family watcher).
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
            _familyChannelId,
            AppConstants.familyChannelName,
            channelDescription: AppConstants.channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            playSound: true,
            sound: _alarmSound,
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
          ),
        ),
      );
    } catch (e) {
      developer.log('showMissedAlert FAILED: $e', name: 'Notif', error: e);
    }
  }

  /// Shows an immediate refill reminder.
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
            _familyChannelId,
            AppConstants.familyChannelName,
            channelDescription: AppConstants.channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            playSound: true,
            sound: _alarmSound,
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
          ),
        ),
      );
    } catch (e) {
      developer.log('showRefillAlert FAILED: $e', name: 'Notif', error: e);
    }
  }

  /// Shows an immediate test notification so the user can verify sound works.
  /// Returns true when the notification was handed to the OS.
  Future<bool> showTestNotification({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      developer.log('showTestNotification: NOT initialized', name: 'Notif');
      return false;
    }
    try {
      await _plugin.show(
        id: 99999,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _soundChannelId,
            AppConstants.channelName,
            channelDescription: AppConstants.channelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            playSound: true,
            sound: _alarmSound,
            enableVibration: true,
            enableLights: true,
            ledColor: const Color(0xFF2E7D32),
            vibrationPattern: _vibrationPattern,
            // Loop the sound like a real reminder, but auto-clear after 8s so
            // the test doesn't ring forever.
            additionalFlags: _insistentFlag,
            timeoutAfter: 8000,
            styleInformation: BigTextStyleInformation(
              body,
              htmlFormatBigText: false,
              contentTitle: title,
              htmlFormatContentTitle: false,
              summaryText: AppConstants.channelName,
            ),
          ),
        ),
      );
      developer.log('Test notification sent OK', name: 'Notif');
      return true;
    } catch (e, st) {
      developer.log('showTestNotification (rich) failed, trying plain: $e\n$st',
          name: 'Notif', error: e, stackTrace: st);
      // Fallback: a minimal notification with no custom sound/style. Isolates
      // whether the alarm sound or big-text style is what the OEM rejects.
      try {
        await _plugin.show(
          id: 99999,
          title: title,
          body: body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _soundChannelId,
              AppConstants.channelName,
              channelDescription: AppConstants.channelDescription,
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
        developer.log('Test notification sent OK (plain)', name: 'Notif');
        return true;
      } catch (e2, st2) {
        developer.log('showTestNotification FAILED (plain too): $e2\n$st2',
            name: 'Notif', error: e2, stackTrace: st2);
        return false;
      }
    }
  }

  static int _alertCounter = 100000;

  bool get soundEnabled => _soundEnabled;

  // ---- Permissions ---------------------------------------------------------

  Future<bool> areNotificationsEnabled() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      return await android.areNotificationsEnabled() ?? true;
    } catch (e) {
      developer.log('areNotificationsEnabled FAILED: $e',
          name: 'Notif', error: e);
      return true;
    }
  }

  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      final granted = await android.requestNotificationsPermission() ?? false;
      developer.log('requestPermission: granted=$granted', name: 'Notif');
      return granted;
    } catch (e) {
      developer.log('requestPermission FAILED: $e', name: 'Notif', error: e);
      return true;
    }
  }

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
      if (android == null) return true; // non-Android: not applicable
      // Pessimistic on null/error: better to show "not granted" and prompt the
      // user than to claim it's granted while scheduling silently degrades to
      // inexact (which only fires when the phone next wakes).
      return await android.canScheduleExactNotifications() ?? false;
    } catch (e) {
      developer.log('canScheduleExact FAILED: $e', name: 'Notif', error: e);
      return false;
    }
  }

  Future<bool> requestExactAlarmPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true;
      await android.requestExactAlarmsPermission();
    } catch (_) {}
    return canScheduleExact();
  }

  /// Android 14+ (API 34) no longer auto-grants USE_FULL_SCREEN_INTENT to
  /// non-call apps. Without it the dose alarm can't take over the lock screen
  /// (it degrades to a normal heads-up). Safe no-op on older versions.
  Future<void> requestFullScreenIntentPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  static const MethodChannel _powerChannel = MethodChannel(
    'com.family.medireminder/power',
  );

  /// True when the app is exempt from battery optimization ("Unrestricted").
  /// When false, Android Doze can delay or drop scheduled dose alarms.
  /// Returns true on non-Android platforms / when the check is unavailable.
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final ok = await _powerChannel.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return ok ?? true;
    } catch (_) {
      return true;
    }
  }

  // ---- Scheduling ----------------------------------------------------------

  /// Schedules a one-off reminder [seconds] from now that looks, sounds and
  /// vibrates exactly like a real dose reminder. Powers the Settings
  /// "test reminder in 1 minute" button so the user can lock the phone and
  /// confirm scheduled reminders actually arrive when the app is closed.
  /// Returns `(scheduled, wasExact)`.
  Future<({bool scheduled, bool exact})> scheduleSelfTest({
    required int seconds,
    required String title,
    required String body,
  }) async {
    if (!_initialized) return (scheduled: false, exact: false);
    final tzWhen = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: seconds));
    final canExact = await canScheduleExact();
    // Always use the SOUND channel — this button exists to verify sound works.
    final details = NotificationDetails(
      android: _buildReminderDetails(
        channelId: _soundChannelId,
        channelName: AppConstants.channelName,
        title: title,
        body: body,
        withActions: false,
      ),
    );

    Future<bool> attempt(AndroidScheduleMode mode) async {
      try {
        await _plugin.zonedSchedule(
          id: 99998,
          title: title,
          body: body,
          scheduledDate: tzWhen,
          notificationDetails: details,
          androidScheduleMode: mode,
        );
        return true;
      } catch (e, st) {
        developer.log('scheduleSelfTest attempt ($mode) failed: $e\n$st',
            name: 'Notif', error: e, stackTrace: st);
        return false;
      }
    }

    // alarmClock delivery is always exact and Doze-exempt, and needs no
    // SCHEDULE_EXACT_ALARM grant — the most reliable option, so try it first.
    if (await attempt(AndroidScheduleMode.alarmClock)) {
      return (scheduled: true, exact: true);
    }
    if (canExact &&
        _exactModeUsable &&
        await attempt(AndroidScheduleMode.exactAllowWhileIdle)) {
      return (scheduled: true, exact: true);
    }
    if (await attempt(AndroidScheduleMode.inexactAllowWhileIdle)) {
      return (scheduled: true, exact: false);
    }
    // Last resort: a bare notification with no alarm sound / full-screen intent.
    try {
      await _plugin.zonedSchedule(
        id: 99998,
        title: title,
        body: body,
        scheduledDate: tzWhen,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _soundChannelId,
            AppConstants.channelName,
            channelDescription: AppConstants.channelDescription,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      return (scheduled: true, exact: false);
    } catch (e, st) {
      developer.log('scheduleSelfTest FAILED (all modes): $e\n$st',
          name: 'Notif', error: e, stackTrace: st);
      return (scheduled: false, exact: canExact);
    }
  }

  /// Builds the AndroidNotificationDetails for a medicine reminder notification
  /// with the bundled WAV alarm sound.
  AndroidNotificationDetails _buildReminderDetails({
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required bool withActions,
    String? takenLabel,
    String? snoozeLabel,
    String? skipLabel,
  }) {
    final actions = <AndroidNotificationAction>[];
    if (withActions && takenLabel != null && snoozeLabel != null && skipLabel != null) {
      actions.addAll([
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
      ]);
    }

    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: AppConstants.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      playSound: true,
      // Belt-and-suspenders: WAV sound on BOTH channel AND notification details.
      // Some OEMs (Samsung, Xiaomi, OnePlus) only respect one or the other.
      sound: _alarmSound,
      enableVibration: true,
      enableLights: true,
      ledColor: const Color(0xFF2E7D32),
      ledOnMs: 1000,
      ledOffMs: 500,
      vibrationPattern: _vibrationPattern,
      fullScreenIntent: true,
      // Loop the alarm sound until the user taps TAKEN / SNOOZE / SKIP or
      // dismisses the notification.
      additionalFlags: _insistentFlag,
      styleInformation: BigTextStyleInformation(
        body,
        htmlFormatBigText: false,
        contentTitle: title,
        htmlFormatContentTitle: false,
        summaryText: AppConstants.channelName,
      ),
      actions: actions,
    );
  }

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
    // If time is in the past or very near, fire immediately so user still
    // gets the notification even if the app was closed when it became due.
    final now = tz.TZDateTime.now(tz.local);
    final fireAt = tzWhen.isAfter(now) ? tzWhen : now.add(const Duration(seconds: 2));

    final channel = _soundEnabled ? _soundChannelId : _silentChannelId;
    final chName =
        _soundEnabled ? AppConstants.channelName : AppConstants.silentChannelName;

    final details = NotificationDetails(
      android: _buildReminderDetails(
        channelId: channel,
        channelName: chName,
        title: title,
        body: body,
        withActions: true,
        takenLabel: takenLabel,
        snoozeLabel: snoozeLabel,
        skipLabel: skipLabel,
      ),
    );
    final payload = '${AppConstants.payloadPrefix}$doseId';

    Future<bool> tryMode(AndroidScheduleMode mode) async {
      try {
        await _plugin.zonedSchedule(
          id: doseId,
          title: title,
          body: body,
          scheduledDate: fireAt,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: payload,
        );
        return true;
      } on Exception catch (e) {
        if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
          _exactModeUsable = false; // stop retrying it for the rest of this pass
        }
        developer.log('zonedSchedule ($mode) failed for dose $doseId: $e',
            name: 'Notif', error: e);
        return false;
      }
    }

    // alarmClock first: AlarmManager.setAlarmClock() is exact, fires in Doze,
    // and needs no SCHEDULE_EXACT_ALARM grant — the most reliable option for a
    // medicine alarm. Then exactAllowWhileIdle, then inexact as a last resort.
    if (await tryMode(AndroidScheduleMode.alarmClock)) return true;
    if (exact &&
        _exactModeUsable &&
        await tryMode(AndroidScheduleMode.exactAllowWhileIdle)) {
      return true;
    }
    if (await tryMode(AndroidScheduleMode.inexactAllowWhileIdle)) return true;
    return false;
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: id);
    } catch (_) {}
  }

  @override
  Future<void> cancelAll(List<int> ids) async {
    if (!_initialized) return;
    for (final id in ids) {
      try {
        await _plugin.cancel(id: id);
      } catch (_) {}
    }
  }

  @override
  Future<bool> scheduleAdvanceAlarm({
    required int doseId,
    required int offset,
    required String title,
    required String body,
    required DateTime when,
    required bool exact,
  }) async {
    if (!_initialized) return false;
    final tzWhen = tz.TZDateTime.from(when, tz.local);
    // If advance time is in the past, skip it (the main notification will
    // fire instead).
    if (!tzWhen.isAfter(tz.TZDateTime.now(tz.local))) return false;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _soundChannelId,
        AppConstants.channelName,
        channelDescription: AppConstants.channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        sound: _alarmSound,
        enableVibration: true,
        enableLights: true,
        ledColor: const Color(0xFFFF6D00),
        ledOnMs: 500,
        ledOffMs: 250,
        vibrationPattern: _vibrationPattern,
        fullScreenIntent: true,
        additionalFlags: _insistentFlag,
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: AppConstants.channelName,
        ),
      ),
    );
    final notifId = doseId * 1000 + offset;
    final payload = '${AppConstants.payloadPrefix}$doseId';

    Future<bool> tryMode(AndroidScheduleMode mode) async {
      try {
        await _plugin.zonedSchedule(
          id: notifId,
          title: title,
          body: body,
          scheduledDate: tzWhen,
          notificationDetails: details,
          androidScheduleMode: mode,
          payload: payload,
        );
        return true;
      } on Exception catch (e) {
        if (mode == AndroidScheduleMode.exactAllowWhileIdle) {
          _exactModeUsable = false;
        }
        developer.log('scheduleAdvanceAlarm ($mode) failed: $e',
            name: 'Notif', error: e);
        return false;
      }
    }

    if (await tryMode(AndroidScheduleMode.alarmClock)) return true;
    if (exact &&
        _exactModeUsable &&
        await tryMode(AndroidScheduleMode.exactAllowWhileIdle)) {
      return true;
    }
    return tryMode(AndroidScheduleMode.inexactAllowWhileIdle);
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

  /// Dismisses every scheduled (not yet shown) reminder.
  Future<void> cancelAllPending() async {
    if (!_initialized) return;
    try {
      final requests = await _plugin.pendingNotificationRequests();
      for (final r in requests) {
        await _plugin.cancel(id: r.id);
      }
    } catch (_) {}
  }

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
    } catch (_) {}
  }
}
