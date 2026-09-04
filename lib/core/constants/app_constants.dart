/// Central application constants.
class AppConstants {
  AppConstants._();

  /// How many days of doses are pre-generated and scheduled ahead.
  /// Kept small so the notification reconcile (one platform call per dose ×
  /// advance alarms) finishes in a second or two — the app re-runs it on every
  /// open/resume and the OS boot receiver re-registers after a reboot.
  static const int windowDays = 4;

  /// Default snooze duration (also user-configurable in Settings).
  static const Duration defaultSnooze = Duration(minutes: 10);

  /// Default grace period before a pending dose is treated as missed.
  static const Duration defaultGrace = Duration(minutes: 30);

  /// Notification channel with sound.
  static const String channelId = 'medicine_reminders';
  static const String channelName = 'Medicine Reminders';

  /// Notification channel without sound (used when sound is disabled).
  static const String silentChannelId = 'medicine_reminders_silent';
  static const String silentChannelName = 'Medicine Reminders (Silent)';

  /// Channel for family/watcher alerts (e.g. a missed dose).
  static const String familyChannelId = 'family_alerts';
  static const String familyChannelName = 'Family Alerts';

  static const String channelDescription = 'Medicine dose reminders';

  /// Notification action ids. The notification payload carries the dose id;
  /// the action id tells us what the user chose.
  static const String actionTaken = 'taken';
  static const String actionSnooze = 'snooze';
  static const String actionSkip = 'skip';

  /// Payload prefix used when tapping the notification body (no action).
  static const String payloadPrefix = 'dose:';
}
