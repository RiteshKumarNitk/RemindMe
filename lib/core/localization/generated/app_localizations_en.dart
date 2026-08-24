// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Medicine Reminder';

  @override
  String get navHome => 'Home';

  @override
  String get greetingMorning => 'Good Morning';

  @override
  String get greetingAfternoon => 'Good Afternoon';

  @override
  String get greetingEvening => 'Good Evening';

  @override
  String get homeNextMedicine => 'Next Medicine';

  @override
  String get homeTakeMedicine => 'TAKE MEDICINE';

  @override
  String get homeSkip => 'Skip';

  @override
  String get homeTaken => 'Taken';

  @override
  String get homeRemaining => 'Remaining';

  @override
  String get homeMissed => 'Missed';

  @override
  String get homeTodayMedicines => 'Today\'s Medicines';

  @override
  String get homeNoMedicines => 'No medicines added yet';

  @override
  String get homeNoMoreToday => 'No more medicines today 🎉';

  @override
  String get homeDosesDone => 'doses done';

  @override
  String homeInMin(int minutes) {
    return 'in $minutes min';
  }

  @override
  String homeInHours(int hours) {
    return 'in ${hours}h';
  }

  @override
  String homeInDays(int days) {
    return 'in ${days}d';
  }

  @override
  String homeOverdueMin(int minutes) {
    return '$minutes min late';
  }

  @override
  String homeOverdueHours(int hours) {
    return '${hours}h late';
  }

  @override
  String get homeAddFirst => 'Add your first medicine';

  @override
  String get homeEmptySchedule => 'No reminders for today';

  @override
  String get statusTaken => 'Taken';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get statusMissed => 'Missed';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusSnoozed => 'Snoozed';

  @override
  String get medTitle => 'My Medicines';

  @override
  String get medAdd => 'Add Medicine';

  @override
  String get medEdit => 'Edit Medicine';

  @override
  String get medName => 'Medicine name';

  @override
  String get medNameHint => 'e.g. BP Tablet';

  @override
  String get medDose => 'Dose';

  @override
  String get medDoseHint => 'e.g. 1';

  @override
  String get medDoseUnit => 'Unit';

  @override
  String get medDoseUnitHint => 'e.g. tablet, drop, spoon';

  @override
  String get medNotes => 'Notes (optional)';

  @override
  String get medFoodInstruction => 'Food instruction';

  @override
  String get foodNone => 'No special instruction';

  @override
  String get foodBefore => 'Before food';

  @override
  String get foodAfter => 'After food';

  @override
  String get foodWith => 'With food';

  @override
  String get medFrequency => 'How often?';

  @override
  String get freqEveryDay => 'Every day';

  @override
  String get freqSpecificDays => 'Specific days';

  @override
  String get freqOnce => 'Once';

  @override
  String get freqMultiple => 'Multiple times a day';

  @override
  String get medSelectDays => 'Select days';

  @override
  String get medReminderTime => 'Reminder time';

  @override
  String get medQuickTimes => 'Quick times — one tap';

  @override
  String get medTimeSlotMorning => 'Morning';

  @override
  String get medTimeSlotAfternoon => 'Afternoon';

  @override
  String get medTimeSlotEvening => 'Evening';

  @override
  String get medTimeSlotNight => 'Night';

  @override
  String get medUnitQuick => 'Common units — one tap';

  @override
  String get medUnitMg => 'mg';

  @override
  String get medUnitMl => 'ml';

  @override
  String get medUnitTablet => 'tablet';

  @override
  String get medUnitCapsule => 'capsule';

  @override
  String get medUnitDrop => 'drop';

  @override
  String get medUnitSpoon => 'spoon';

  @override
  String get medAddAnotherTime => 'Add another time';

  @override
  String get medSave => 'Save';

  @override
  String get medDelete => 'Delete';

  @override
  String get medPause => 'Pause';

  @override
  String get medResume => 'Resume';

  @override
  String get medActive => 'Active';

  @override
  String get medInactive => 'Paused';

  @override
  String get medDeleteTitle => 'Delete medicine?';

  @override
  String medDeleteBody(String name) {
    return 'This will remove \"$name\" and its future reminders. This cannot be undone.';
  }

  @override
  String get medDeleted => 'Medicine deleted';

  @override
  String get medSaved => 'Medicine saved';

  @override
  String get medPausedMsg => 'Reminders paused';

  @override
  String get medResumedMsg => 'Reminders resumed';

  @override
  String get medNoMedicines =>
      'No medicines yet.\nTap \"Add Medicine\" to get started.';

  @override
  String get medOnceDate => 'Date';

  @override
  String get medTime => 'Time';

  @override
  String get histTitle => 'History';

  @override
  String get histToday => 'Today';

  @override
  String get histThisWeek => 'This Week';

  @override
  String get histAll => 'All';

  @override
  String get histAdherence => 'Adherence';

  @override
  String get histTakenCount => 'Taken';

  @override
  String get histMissedCount => 'Missed';

  @override
  String get histSkippedCount => 'Skipped';

  @override
  String get histPendingCount => 'Pending';

  @override
  String get histEmpty => 'No history yet';

  @override
  String histTotal(int count) {
    return 'Total: $count';
  }

  @override
  String get setTitle => 'Settings';

  @override
  String get setLanguage => 'Language';

  @override
  String get setNotificationSound => 'Notification sound';

  @override
  String get setVoiceReminder => 'Voice reminder';

  @override
  String get setVoiceOn => 'Speak the reminder aloud';

  @override
  String get setSnoozeDuration => 'Snooze duration';

  @override
  String get setGracePeriod => 'Mark missed after';

  @override
  String get setDarkMode => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get setAbout => 'About';

  @override
  String get setPermissions => 'Permissions';

  @override
  String get setNotifyPermission => 'Notification permission';

  @override
  String get setExactAlarm => 'Exact alarm permission';

  @override
  String get setBattery => 'Battery / background';

  @override
  String get permissionGranted => 'Granted';

  @override
  String get permissionDenied => 'Not granted — tap to allow';

  @override
  String get setNotifDesc => 'Allow reminders to appear';

  @override
  String get setExactDesc => 'Allow reminders at the exact time';

  @override
  String get setBatteryDesc => 'Keep reminders working in the background';

  @override
  String get aboutBody =>
      'Medicine Reminder is a reminder and tracking tool only. It does not provide medical advice. Always follow your doctor\'s instructions.';

  @override
  String get notifTitle => '💊 Medicine Time';

  @override
  String notifBody(String name, String dose) {
    return 'Take $name — $dose';
  }

  @override
  String get notifActionTaken => 'TAKEN';

  @override
  String notifActionSnooze(int minutes) {
    return 'Snooze $minutes min';
  }

  @override
  String get notifActionSkip => 'SKIP';

  @override
  String get permNotifTitle => 'Allow notifications?';

  @override
  String get permNotifBody =>
      'Reminders appear as notifications, even when the app is closed. Please allow notifications.';

  @override
  String get permExactTitle => 'Allow exact alarms?';

  @override
  String get permExactBody =>
      'For reminders to ring at the exact time, Android needs your permission. The system settings will open — please turn on \"Allow exact alarms\" for this app.';

  @override
  String get permOk => 'OK';

  @override
  String get permCancel => 'Not now';

  @override
  String get obWelcome => 'Welcome!';

  @override
  String get obTitle => 'Medicine Reminder';

  @override
  String get obBody =>
      'I will remind you to take your medicines on time. Setting this up takes just one minute.';

  @override
  String get obName => 'What should I call you? (optional)';

  @override
  String get obNameHint => 'e.g. Mom';

  @override
  String get obStart => 'Start';

  @override
  String get obSkip => 'Skip for now';

  @override
  String voiceTimeToTake(String name, String dose) {
    return 'It is time to take your medicine. $name, $dose.';
  }

  @override
  String get voiceTaken => 'Well done! Medicine taken.';

  @override
  String get voiceSkipped => 'Medicine skipped.';

  @override
  String get undo => 'Undo';

  @override
  String get undoTaken => 'Medicine marked as taken';

  @override
  String get undoSkipped => 'Medicine skipped';

  @override
  String get homeSkipConfirmTitle => 'Skip this dose?';

  @override
  String homeSkipConfirmBody(String name) {
    return 'Are you sure you want to skip $name? This will be marked as skipped.';
  }

  @override
  String get btnSave => 'Save';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnClose => 'Close';

  @override
  String minutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get speakReminder => 'Speak reminder';

  @override
  String get missedAlertTitle => '⚠️ Missed medicine';

  @override
  String missedAlertBody(String name, String time) {
    return '$name at $time was not taken';
  }

  @override
  String get familySync => 'Family & Sync';

  @override
  String get familySyncDesc => 'Share medicines and history with family';

  @override
  String get familySyncIntro =>
      'Family can see whether medicines were taken and get an alert when a dose is missed. Everything stays private to your family.';

  @override
  String get syncRolePrimary => 'I take medicines here';

  @override
  String get syncRolePrimaryDesc =>
      'This phone belongs to the person taking medicines';

  @override
  String get syncRoleWatcher => 'I am family — I want to help';

  @override
  String get syncRoleWatcherDesc =>
      'Watch over medicines and get missed-dose alerts';

  @override
  String get syncCodeLabel => 'Family code';

  @override
  String get syncCodeHint => 'Enter the 6-letter code';

  @override
  String get syncJoin => 'Join family';

  @override
  String get syncCreate => 'Create family';

  @override
  String get syncCopied => 'Code copied';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncOn => 'Sync is on';

  @override
  String get syncOff => 'Sync is off';

  @override
  String syncLastSync(String time) {
    return 'Last synced: $time';
  }

  @override
  String get syncNever => 'Never';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get syncDisable => 'Turn off sync';

  @override
  String get syncDisableConfirm =>
      'Turning off sync removes this phone from the family. Medicines stay on this phone.';

  @override
  String get syncNotConfigured =>
      'Cloud sync is not set up for this app yet (add google-services.json). The app works fully offline without it.';

  @override
  String get missedAlerts => 'Missed-dose alerts';

  @override
  String get missedAlertsDesc => 'Get an alert when a medicine is missed';

  @override
  String get syncStatusSynced => 'All synced';

  @override
  String get syncStatusSyncing => 'Syncing…';

  @override
  String syncPendingCount(int count) {
    return '$count changes waiting to sync';
  }

  @override
  String get syncRetrying => 'Will retry automatically';

  @override
  String get syncCodeShare => 'Share this code with family';

  @override
  String get caregiverTitle => 'Family Dashboard';

  @override
  String get caregiverDesc => 'Weekly adherence and today\'s doses';

  @override
  String get caregiverRefresh => 'Refresh';

  @override
  String get caregiverThisWeek => 'This Week';
}
