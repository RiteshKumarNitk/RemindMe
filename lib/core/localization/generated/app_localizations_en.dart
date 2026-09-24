// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'DoseWise';

  @override
  String get navHome => 'Home';

  @override
  String get navFamily => 'Family';

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
  String get homeWellnessSubtitle => 'Here is your wellness plan for today.';

  @override
  String get homeUpcomingDose => 'Upcoming Dose';

  @override
  String get homeMarkAsTaken => 'Mark as Taken';

  @override
  String get homeScheduleTitle => 'Today\'s Schedule';

  @override
  String get homeLogNow => 'Log Now';

  @override
  String get homeDailyProgress => 'Today\'s progress';

  @override
  String homeProgressOf(int taken, int total) {
    return '$taken of $total medicines taken';
  }

  @override
  String get homeMissedTitle => 'You missed this medicine';

  @override
  String get homeMissedBody =>
      'If you haven\'t taken it yet, follow your normal medication instructions.';

  @override
  String get homeMoreTools => 'More tools';

  @override
  String get homeEmptyBody =>
      'Add your first medicine and DoseWise will remind you when it is time to take it.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get errorBody => 'We couldn\'t load your medicines. Please try again.';

  @override
  String get errorRetry => 'Try again';

  @override
  String get medConfirmTime => 'Confirm time';

  @override
  String get medOptional => 'Optional details';

  @override
  String get medDetailsTitle => 'Medicine details';

  @override
  String get setGroupReminders => 'Reminders';

  @override
  String get homeQuickActions => 'Quick actions';

  @override
  String get qaWeeklyCalendar => 'Weekly Calendar';

  @override
  String get qaAdherenceReport => 'Adherence Report';

  @override
  String get qaDoctorReport => 'Doctor Report';

  @override
  String get qaVoiceMode => 'Voice Mode';

  @override
  String get qaVitalsLog => 'Vitals Log';

  @override
  String get navMeds => 'Meds';

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
  String get homeDueNow => 'Due now!';

  @override
  String get homeTakeNowBanner => 'Take now!';

  @override
  String get homeTakeNowSubtitle => 'A dose is due';

  @override
  String get alarmTitle => 'Time to take your medicine!';

  @override
  String alarmSubtitle(String name, String dose) {
    return '$name — $dose';
  }

  @override
  String get alarmSnooze => 'Snooze';

  @override
  String get alarmLater => 'I\'ll take it later';

  @override
  String homeOverdueMin(int minutes) {
    return '$minutes min late';
  }

  @override
  String get medPresetWeekdays => 'Weekdays';

  @override
  String get medPresetWeekends => 'Weekends';

  @override
  String get medDuplicate => 'Duplicate';

  @override
  String get medDuplicateHint => 'Create a copy of this medicine';

  @override
  String get pauseAll => 'Pause All Medicines';

  @override
  String get pauseAllConfirm =>
      'This will pause all active medicines and their reminders. You can resume them later.';

  @override
  String get resumeAll => 'Resume All';

  @override
  String homeStreak(int days) {
    return '$days-day streak! Keep it up! 🎉';
  }

  @override
  String get homeBatchMarkAll => 'Mark all as taken';

  @override
  String get homeAllDoneToday => 'All done for today! 🎉';

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
  String get medSearch => 'Search medicines...';

  @override
  String get medSearchClear => 'Clear search';

  @override
  String get medSearchEmpty => 'No medicines match your search';

  @override
  String get medStockTracking => 'Stock tracking (optional)';

  @override
  String get medStockCountHint => 'Current pills (e.g. 30)';

  @override
  String get medRefillAtHint => 'Remind at (e.g. 5)';

  @override
  String get medRefillTitle => 'Time to refill!';

  @override
  String medRefillBody(String name, int remaining) {
    return '$name is running low ($remaining left). Time to refill.';
  }

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
  String get histScheduled => 'Scheduled';

  @override
  String get histActual => 'Actual';

  @override
  String histShowing(String label, int count) {
    return 'Showing: $label ($count)';
  }

  @override
  String medActiveCount(int active, int total) {
    return '$active of $total active';
  }

  @override
  String medStockLeft(int count) {
    return '$count left';
  }

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
  String get histExport => 'Export CSV';

  @override
  String get medConflictTitle => 'Schedule conflict';

  @override
  String medConflictBody(String names) {
    return 'These medicines are already scheduled at the same time: $names. Continue anyway?';
  }

  @override
  String get histTrendGood => 'Adherence is looking good!';

  @override
  String get histTrendNeedsWork => 'Adherence needs improvement';

  @override
  String get setData => 'Data';

  @override
  String get setExportJson => 'Export backup';

  @override
  String get setExportJsonDesc => 'Save all medicines and history as JSON';

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
  String get setAdvanceAlarm => 'Advance alarm';

  @override
  String get setAdvanceAlarmDesc => 'Start alarm sound before dose time';

  @override
  String get off => 'Off';

  @override
  String get testNotification => 'Test Notification Sound';

  @override
  String get testNotifSent => 'Test notification sent! Check your sound.';

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
  String get setBatteryRestricted => 'Restricted';

  @override
  String get setBatteryWarning =>
      'Optional: on some phones the battery saver can delay reminders. Tap to set DoseWise to \"Unrestricted\".';

  @override
  String get testNotifFailed =>
      'Couldn\'t send a test notification. Open Android settings and allow notifications for DoseWise.';

  @override
  String get setTestScheduled => 'Test a scheduled reminder (1 min)';

  @override
  String get setTestScheduledSent =>
      'A reminder is set for ~1 minute from now. Close the app and lock your phone — it should ring and vibrate.';

  @override
  String get setTestScheduledInexact =>
      'Set for ~1 minute, but exact alarms are off, so it may be late. Turn on exact alarms for on-time reminders.';

  @override
  String get setTestScheduledFailed =>
      'Couldn\'t schedule the test. Check that notifications are allowed.';

  @override
  String setScheduledCount(int count) {
    return 'Reminders scheduled on this phone: $count';
  }

  @override
  String get aboutBody =>
      'DoseWise is a reminder and tracking tool only. It does not provide medical advice. Always follow your doctor\'s instructions.';

  @override
  String get notifTitle => '💊 Medicine Time';

  @override
  String notifTitleFor(String name) {
    return '💊 Time for $name';
  }

  @override
  String notifBody(String name, String info) {
    return 'Take $name — $info';
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
  String get obTitle => 'DoseWise';

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
  String get obBatteryWhy => 'Why is this needed?';

  @override
  String get obBatteryHow =>
      'Open your phone\'s Settings, find this app, and turn off \'Battery optimization\' or select \'Unrestricted\'. This keeps reminders working even when the app is closed.';

  @override
  String voiceTimeToTake(String name, String dose) {
    return 'It is time to take your medicine. $name, $dose.';
  }

  @override
  String get voiceTaken => 'Well done! Medicine taken.';

  @override
  String get voiceSkipped => 'Medicine skipped.';

  @override
  String get voiceSnoozed => 'Reminder snoozed.';

  @override
  String homeSnoozedUntil(String time) {
    return 'Snoozed to $time';
  }

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
  String get syncSetupHint =>
      'Create a code so family can help with your medicines — and enter a family member\'s code to help with theirs. You can do both.';

  @override
  String get syncCreateCode => 'Create my family code';

  @override
  String get syncHaveCode => 'I have a family code';

  @override
  String get syncJoinAnother => 'Join another family code';

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
  String get syncPrimaryHint =>
      'On the patient\'s phone, open Family Sync and tap \"I take medicines here\" to get this code.';

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
  String get syncErrorPermission =>
      'The cloud database rejected the request. This Firebase project\'s Firestore security rules haven\'t been set up — deploy firestore.rules or paste them into Firebase Console → Firestore → Rules.';

  @override
  String get syncErrorNetwork =>
      'Couldn\'t reach the server. Check your internet connection and try again.';

  @override
  String get syncErrorAuth =>
      'Sign-in was rejected. In the Firebase console, enable Anonymous and Google sign-in, and register this app\'s SHA-1.';

  @override
  String get syncErrorDetail => 'Details';

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

  @override
  String get notifDiagnostics => 'Notification Diagnostics';

  @override
  String get notifFixAll => 'Fix All';

  @override
  String get notifStatusOk => 'All permissions are set correctly';

  @override
  String get notifStatusNeedsFix =>
      'Some settings may prevent reminders from working';

  @override
  String get notifOpenSystemSettings => 'Open System Settings';

  @override
  String get syncGoogleSignIn => 'Continue with Google';

  @override
  String get syncSignOut => 'Sign out';

  @override
  String get syncSignInFailed =>
      'Sign-in failed. Please check your internet connection and try again.';

  @override
  String get loginSubtitle =>
      'Sign in to sync your medicines with family members, or use the app offline.';

  @override
  String get loginWithGoogle => 'Continue with Google';

  @override
  String get loginOr => 'or';

  @override
  String get loginSkip => 'Use Offline';

  @override
  String get loginOfflineNote => 'You can always sign in later from Settings.';

  @override
  String get familySyncNotConfigured =>
      'Firebase is not configured. Family sync requires Firebase setup. The app works fully offline without it.';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profilePersonalInfo => 'Personal Information';

  @override
  String get profileAccount => 'Account';

  @override
  String get profileAge => 'Age';

  @override
  String get profileAgeHint => 'e.g. 65';

  @override
  String get profileEditInfo => 'Edit Information';

  @override
  String get profileSaved => 'Profile updated';

  @override
  String get profileSignOut => 'Sign Out';

  @override
  String get profileSignOutDesc => 'Sign out of your Google account';

  @override
  String get profileSignOutConfirm =>
      'Are you sure you want to sign out? Your data stays on this phone.';

  @override
  String get profileSignedOut => 'Signed out successfully';

  @override
  String get profileDangerZone => 'Danger zone';

  @override
  String get profileDeleteAccount => 'Delete my account & data';

  @override
  String get profileDeleteAccountDesc =>
      'Permanently erase everything on this device, and your account if signed in';

  @override
  String get profileDeleteAccountConfirmTitle => 'Delete everything?';

  @override
  String get profileDeleteAccountConfirmBody =>
      'This permanently deletes every medicine, dose and history entry stored on this device. This cannot be undone.';

  @override
  String get profileDeleteAccountConfirmBodySignedIn =>
      'It will also delete your signed-in account and remove you from any family you\'ve joined.';

  @override
  String get profileDeleteAccountButton => 'Delete everything';

  @override
  String get profileDeleteAccountReauthTitle => 'Please sign in again';

  @override
  String get profileDeleteAccountReauthBody =>
      'For your security, deleting your account needs a recent sign-in. Sign in again, then try again.';

  @override
  String get profileDeleteAccountReauthButton => 'Sign in again';

  @override
  String get profileDeleteAccountDone => 'Everything has been deleted.';

  @override
  String get profileDeleteAccountPartial =>
      'Your data on this device was deleted. Some account cleanup couldn\'t finish — you can try again later while online.';

  @override
  String get profileDeleteAccountOwnerNote =>
      'You created a family household, so a small amount of membership info stays until another member removes it.';

  @override
  String get profileSignInPrompt =>
      'Sign in with Google to sync your medicines with family members across devices.';

  @override
  String get profileWelcomeBack => 'Welcome back!';

  @override
  String get profileSignedIn => 'Signed in with Google';

  @override
  String get profileOfflineMode => 'Offline Mode';

  @override
  String get profileGuestUser => 'Guest User';

  @override
  String get profileNoName => 'No name set';

  @override
  String get profileNotSet => 'Not set';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileNoInfoYet =>
      'No personal information yet. Tap \"Edit Information\" to add your name and age.';

  @override
  String get navProfile => 'Profile';

  @override
  String get elapsedJustNow => 'just now';

  @override
  String elapsedMinAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String elapsedHourMinAgo(int hours, int minutes) {
    return '${hours}h ${minutes}m ago';
  }

  @override
  String get hcCareSection => 'Care';

  @override
  String get hcFindTitle => 'Find healthcare';

  @override
  String get hcFindSubtitle => 'Search clinics, hospitals and doctors';

  @override
  String get hcUpcomingAppointment => 'Upcoming appointment';

  @override
  String get hcNoUpcomingAppointment => 'No upcoming appointment';

  @override
  String get hcViewAllAppointments => 'My appointments';

  @override
  String get hcSearchHint => 'Clinic, hospital or doctor';

  @override
  String get hcSearchAction => 'Search';

  @override
  String get hcAllTypes => 'All';

  @override
  String get hcFilterType => 'Provider type';

  @override
  String get hcTypeHospital => 'Hospitals';

  @override
  String get hcTypeClinic => 'Clinics';

  @override
  String get hcTypePolyclinic => 'Polyclinics';

  @override
  String get hcTypeDiagnostic => 'Diagnostic centres';

  @override
  String get hcTypeOther => 'Other providers';

  @override
  String get hcProvidersTitle => 'Clinics & hospitals';

  @override
  String get hcDoctorsTitle => 'Doctors';

  @override
  String get hcSearchEmptyTitle => 'No healthcare providers found';

  @override
  String get hcSearchEmptyBody =>
      'Try a different name, provider type or city.';

  @override
  String get hcNoDoctorsTitle => 'No doctors listed';

  @override
  String get hcNoDoctorsBody =>
      'This provider has not published any bookable doctors yet.';

  @override
  String get hcNoDoctorsShort => 'No doctors listed';

  @override
  String get hcLoadFailedTitle => 'We couldn\'t load this';

  @override
  String get hcLoadFailedBody =>
      'Check your internet connection and try again.';

  @override
  String get hcOfflineTitle => 'You are offline';

  @override
  String get hcRetry => 'Try again';

  @override
  String get hcLoadMore => 'Load more';

  @override
  String get hcVerified => 'Verified';

  @override
  String hcDoctorCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors',
      one: '1 doctor',
      zero: 'No doctors listed',
    );
    return '$_temp0';
  }

  @override
  String get hcAbout => 'About';

  @override
  String get hcContact => 'Contact';

  @override
  String get hcLocations => 'Locations';

  @override
  String get hcCall => 'Call';

  @override
  String get hcEmail => 'Email';

  @override
  String get hcWebsite => 'Website';

  @override
  String get hcBookAppointment => 'Book appointment';

  @override
  String get hcChooseBranchTitle => 'Choose a branch';

  @override
  String get hcChooseBranchBody =>
      'This provider has more than one location. Pick the one you are visiting.';

  @override
  String get hcBranch => 'Branch';

  @override
  String get hcSpecialty => 'Speciality';

  @override
  String get hcQualifications => 'Qualifications';

  @override
  String hcExperience(int years) {
    String _temp0 = intl.Intl.pluralLogic(
      years,
      locale: localeName,
      other: '$years years experience',
      one: '1 year experience',
    );
    return '$_temp0';
  }

  @override
  String get hcLanguages => 'Languages';

  @override
  String hcConsultationFee(String fee) {
    return '$fee per visit';
  }

  @override
  String get hcRegistration => 'Registration';

  @override
  String get hcSelectDateTitle => 'Pick a date';

  @override
  String get hcSelectTimeTitle => 'Pick a time';

  @override
  String hcClinicTimeNote(String zone) {
    return 'Times are in the clinic\'s time zone ($zone).';
  }

  @override
  String get hcNoSlotsTitle => 'No available appointments';

  @override
  String get hcNoSlotsBody =>
      'There are no free times on this day. Try another date.';

  @override
  String get hcSlotsLoadFailed =>
      'We couldn\'t check this day. Please try again.';

  @override
  String get hcContinue => 'Continue';

  @override
  String get hcYourDetailsTitle => 'Your details';

  @override
  String get hcYourDetailsBody =>
      'The clinic registers you as a patient with these details.';

  @override
  String get hcFirstName => 'First name';

  @override
  String get hcLastName => 'Last name';

  @override
  String get hcPhone => 'Phone number';

  @override
  String get hcOptional => 'Optional';

  @override
  String get hcReasonTitle => 'Reason for visit';

  @override
  String get hcReasonHint => 'e.g. fever since two days';

  @override
  String get hcReviewTitle => 'Check and confirm';

  @override
  String get hcConfirmBooking => 'Confirm appointment';

  @override
  String get hcBookingConfirmedTitle => 'Appointment confirmed';

  @override
  String get hcBookingRequestedTitle => 'Appointment requested';

  @override
  String get hcBookingPendingBody =>
      'The clinic will confirm your appointment. You can follow it in My appointments.';

  @override
  String get hcBookingReferenceLabel => 'Reference';

  @override
  String get hcViewAppointment => 'View appointment';

  @override
  String get hcDone => 'Done';

  @override
  String get hcSlotTakenTitle => 'That time was just taken';

  @override
  String get hcSlotTakenBody =>
      'Someone else booked it first. Please choose another time.';

  @override
  String get hcFieldRequired => 'This is needed.';

  @override
  String get hcEmailInvalid => 'Enter a valid email address.';

  @override
  String get hcPasswordTooShort => 'Use at least 10 characters.';

  @override
  String get hcBookingFailedTitle => 'We couldn\'t book this appointment';

  @override
  String get hcBookingFailedBody =>
      'Nothing was booked. You can try again or pick another time.';

  @override
  String get hcMyAppointments => 'My appointments';

  @override
  String get hcTabUpcoming => 'Upcoming';

  @override
  String get hcTabPast => 'Past';

  @override
  String get hcTabCancelled => 'Cancelled';

  @override
  String get hcNoUpcomingTitle => 'No upcoming appointments';

  @override
  String get hcNoUpcomingBody =>
      'Find a clinic, choose a doctor and book a visit — it will appear here.';

  @override
  String get hcNoPastTitle => 'No past appointments';

  @override
  String get hcNoPastBody => 'Visits you complete will show up here.';

  @override
  String get hcNoCancelledTitle => 'Nothing cancelled';

  @override
  String get hcNoCancelledBody =>
      'Appointments you cancel will be listed here.';

  @override
  String get hcAppointmentsSignInTitle => 'Sign in to see your appointments';

  @override
  String get hcAppointmentsSignInBody =>
      'Your appointments are stored in your clinic account.';

  @override
  String get hcStatusRequested => 'Requested';

  @override
  String get hcStatusConfirmed => 'Confirmed';

  @override
  String get hcStatusCheckedIn => 'Checked in';

  @override
  String get hcStatusWaiting => 'Waiting';

  @override
  String get hcStatusInConsultation => 'In consultation';

  @override
  String get hcStatusCompleted => 'Completed';

  @override
  String get hcStatusCancelled => 'Cancelled';

  @override
  String get hcStatusNoShow => 'Missed';

  @override
  String get hcStatusRescheduled => 'Rescheduled';

  @override
  String get hcStatusUnknown => 'Unknown';

  @override
  String get hcWhen => 'When';

  @override
  String get hcWhere => 'Where';

  @override
  String get hcDoctorLabel => 'Doctor';

  @override
  String get hcReasonLabel => 'Reason';

  @override
  String get hcNotesLabel => 'Notes';

  @override
  String get hcCancelAppointment => 'Cancel appointment';

  @override
  String get hcKeepAppointment => 'Keep appointment';

  @override
  String get hcCancelConfirmTitle => 'Cancel this appointment?';

  @override
  String get hcCancelReasonHint => 'Reason (optional)';

  @override
  String get hcAppointmentCancelled => 'Appointment cancelled';

  @override
  String get hcRescheduleAction => 'Reschedule';

  @override
  String get hcRescheduleTitle => 'Choose a new time';

  @override
  String get hcRescheduledMessage => 'Appointment moved';

  @override
  String get hcSessionExpired =>
      'Your session has ended. Please sign in again.';

  @override
  String get hcQueueTitle => 'Your queue';

  @override
  String hcQueueToken(int token) {
    return 'Token $token';
  }

  @override
  String hcQueueAhead(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients ahead of you',
      one: '1 patient ahead of you',
    );
    return '$_temp0';
  }

  @override
  String get hcQueueYouAreNext => 'You are next in line';

  @override
  String get hcQueueCheckInNote =>
      'Please check in at the clinic reception when you arrive. Your token appears here once they add you to the queue.';

  @override
  String get hcQueueCalled => 'Please go to the doctor\'s room';

  @override
  String get hcQueueInConsultation => 'You are with the doctor now';

  @override
  String get hcQueueFinished => 'This visit is finished';

  @override
  String get hcSignInTitle => 'Sign in to book';

  @override
  String get hcSignInBody =>
      'Booking uses your clinic account — the same email and password you use on the clinic website.';

  @override
  String get hcSignIn => 'Sign in';

  @override
  String get hcSignOut => 'Sign out';

  @override
  String get hcEmailLabel => 'Email';

  @override
  String get hcPasswordLabel => 'Password';

  @override
  String get hcFullNameLabel => 'Full name';

  @override
  String get hcCreateAccount => 'Create account';

  @override
  String get hcHaveAccount => 'Already have an account? Sign in';

  @override
  String get hcNoAccount => 'New here? Create an account';

  @override
  String hcSignedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get hcSignInFailed =>
      'We couldn\'t sign you in. Check your email and password.';

  @override
  String get hcApiSettingsTitle => 'Clinic server (QA)';

  @override
  String get hcApiSettingsHint => 'Base address of the clinic platform API';

  @override
  String get hcApiSettingsSaved => 'Server address saved';

  @override
  String get hcApiSettingsReset => 'Reset to default';

  @override
  String get hcFiltersTitle => 'Filters';

  @override
  String get hcCityLabel => 'City';

  @override
  String get hcCityHint => 'e.g. Jaipur';

  @override
  String get hcApply => 'Apply';

  @override
  String get hcClear => 'Clear';

  @override
  String hcRelInMinutes(int minutes) {
    return 'In $minutes min';
  }

  @override
  String hcRelInHours(int hours) {
    return 'In $hours h';
  }

  @override
  String get hcRelStartingSoon => 'Starting soon';

  @override
  String get hcRelToday => 'Today';

  @override
  String get hcRelTomorrow => 'Tomorrow';

  @override
  String get hcTimeUnknown => 'Time to be confirmed';

  @override
  String get hcUnavailableTitle => 'This provider is no longer listed';

  @override
  String get hcUnavailableBody =>
      'It may have been unpublished. Go back and choose another provider.';
}
