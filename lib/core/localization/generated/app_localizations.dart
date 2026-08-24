import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine Reminder'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get greetingMorning;

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get greetingAfternoon;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get greetingEvening;

  /// No description provided for @homeNextMedicine.
  ///
  /// In en, this message translates to:
  /// **'Next Medicine'**
  String get homeNextMedicine;

  /// No description provided for @homeTakeMedicine.
  ///
  /// In en, this message translates to:
  /// **'TAKE MEDICINE'**
  String get homeTakeMedicine;

  /// No description provided for @homeSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get homeSkip;

  /// No description provided for @homeTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get homeTaken;

  /// No description provided for @homeRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get homeRemaining;

  /// No description provided for @homeMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get homeMissed;

  /// No description provided for @homeTodayMedicines.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Medicines'**
  String get homeTodayMedicines;

  /// No description provided for @homeNoMedicines.
  ///
  /// In en, this message translates to:
  /// **'No medicines added yet'**
  String get homeNoMedicines;

  /// No description provided for @homeNoMoreToday.
  ///
  /// In en, this message translates to:
  /// **'No more medicines today 🎉'**
  String get homeNoMoreToday;

  /// No description provided for @homeDosesDone.
  ///
  /// In en, this message translates to:
  /// **'doses done'**
  String get homeDosesDone;

  /// No description provided for @homeInMin.
  ///
  /// In en, this message translates to:
  /// **'in {minutes} min'**
  String homeInMin(int minutes);

  /// No description provided for @homeInHours.
  ///
  /// In en, this message translates to:
  /// **'in {hours}h'**
  String homeInHours(int hours);

  /// No description provided for @homeInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days}d'**
  String homeInDays(int days);

  /// No description provided for @homeOverdueMin.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min late'**
  String homeOverdueMin(int minutes);

  /// No description provided for @homeOverdueHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h late'**
  String homeOverdueHours(int hours);

  /// No description provided for @homeAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first medicine'**
  String get homeAddFirst;

  /// No description provided for @homeEmptySchedule.
  ///
  /// In en, this message translates to:
  /// **'No reminders for today'**
  String get homeEmptySchedule;

  /// No description provided for @statusTaken.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get statusTaken;

  /// No description provided for @statusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get statusSkipped;

  /// No description provided for @statusMissed.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get statusMissed;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusSnoozed.
  ///
  /// In en, this message translates to:
  /// **'Snoozed'**
  String get statusSnoozed;

  /// No description provided for @medTitle.
  ///
  /// In en, this message translates to:
  /// **'My Medicines'**
  String get medTitle;

  /// No description provided for @medAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Medicine'**
  String get medAdd;

  /// No description provided for @medEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Medicine'**
  String get medEdit;

  /// No description provided for @medName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get medName;

  /// No description provided for @medNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. BP Tablet'**
  String get medNameHint;

  /// No description provided for @medDose.
  ///
  /// In en, this message translates to:
  /// **'Dose'**
  String get medDose;

  /// No description provided for @medDoseHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1'**
  String get medDoseHint;

  /// No description provided for @medDoseUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get medDoseUnit;

  /// No description provided for @medDoseUnitHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. tablet, drop, spoon'**
  String get medDoseUnitHint;

  /// No description provided for @medNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get medNotes;

  /// No description provided for @medFoodInstruction.
  ///
  /// In en, this message translates to:
  /// **'Food instruction'**
  String get medFoodInstruction;

  /// No description provided for @foodNone.
  ///
  /// In en, this message translates to:
  /// **'No special instruction'**
  String get foodNone;

  /// No description provided for @foodBefore.
  ///
  /// In en, this message translates to:
  /// **'Before food'**
  String get foodBefore;

  /// No description provided for @foodAfter.
  ///
  /// In en, this message translates to:
  /// **'After food'**
  String get foodAfter;

  /// No description provided for @foodWith.
  ///
  /// In en, this message translates to:
  /// **'With food'**
  String get foodWith;

  /// No description provided for @medFrequency.
  ///
  /// In en, this message translates to:
  /// **'How often?'**
  String get medFrequency;

  /// No description provided for @freqEveryDay.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get freqEveryDay;

  /// No description provided for @freqSpecificDays.
  ///
  /// In en, this message translates to:
  /// **'Specific days'**
  String get freqSpecificDays;

  /// No description provided for @freqOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get freqOnce;

  /// No description provided for @freqMultiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple times a day'**
  String get freqMultiple;

  /// No description provided for @medSelectDays.
  ///
  /// In en, this message translates to:
  /// **'Select days'**
  String get medSelectDays;

  /// No description provided for @medReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get medReminderTime;

  /// No description provided for @medQuickTimes.
  ///
  /// In en, this message translates to:
  /// **'Quick times — one tap'**
  String get medQuickTimes;

  /// No description provided for @medTimeSlotMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get medTimeSlotMorning;

  /// No description provided for @medTimeSlotAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get medTimeSlotAfternoon;

  /// No description provided for @medTimeSlotEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get medTimeSlotEvening;

  /// No description provided for @medTimeSlotNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get medTimeSlotNight;

  /// No description provided for @medUnitQuick.
  ///
  /// In en, this message translates to:
  /// **'Common units — one tap'**
  String get medUnitQuick;

  /// No description provided for @medUnitMg.
  ///
  /// In en, this message translates to:
  /// **'mg'**
  String get medUnitMg;

  /// No description provided for @medUnitMl.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get medUnitMl;

  /// No description provided for @medUnitTablet.
  ///
  /// In en, this message translates to:
  /// **'tablet'**
  String get medUnitTablet;

  /// No description provided for @medUnitCapsule.
  ///
  /// In en, this message translates to:
  /// **'capsule'**
  String get medUnitCapsule;

  /// No description provided for @medUnitDrop.
  ///
  /// In en, this message translates to:
  /// **'drop'**
  String get medUnitDrop;

  /// No description provided for @medUnitSpoon.
  ///
  /// In en, this message translates to:
  /// **'spoon'**
  String get medUnitSpoon;

  /// No description provided for @medAddAnotherTime.
  ///
  /// In en, this message translates to:
  /// **'Add another time'**
  String get medAddAnotherTime;

  /// No description provided for @medSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get medSave;

  /// No description provided for @medDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get medDelete;

  /// No description provided for @medPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get medPause;

  /// No description provided for @medResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get medResume;

  /// No description provided for @medActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get medActive;

  /// No description provided for @medInactive.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get medInactive;

  /// No description provided for @medDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete medicine?'**
  String get medDeleteTitle;

  /// No description provided for @medDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This will remove \"{name}\" and its future reminders. This cannot be undone.'**
  String medDeleteBody(String name);

  /// No description provided for @medDeleted.
  ///
  /// In en, this message translates to:
  /// **'Medicine deleted'**
  String get medDeleted;

  /// No description provided for @medSaved.
  ///
  /// In en, this message translates to:
  /// **'Medicine saved'**
  String get medSaved;

  /// No description provided for @medPausedMsg.
  ///
  /// In en, this message translates to:
  /// **'Reminders paused'**
  String get medPausedMsg;

  /// No description provided for @medResumedMsg.
  ///
  /// In en, this message translates to:
  /// **'Reminders resumed'**
  String get medResumedMsg;

  /// No description provided for @medNoMedicines.
  ///
  /// In en, this message translates to:
  /// **'No medicines yet.\nTap \"Add Medicine\" to get started.'**
  String get medNoMedicines;

  /// No description provided for @medOnceDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get medOnceDate;

  /// No description provided for @medTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get medTime;

  /// No description provided for @histTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get histTitle;

  /// No description provided for @histToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get histToday;

  /// No description provided for @histThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get histThisWeek;

  /// No description provided for @histAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get histAll;

  /// No description provided for @histAdherence.
  ///
  /// In en, this message translates to:
  /// **'Adherence'**
  String get histAdherence;

  /// No description provided for @histTakenCount.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get histTakenCount;

  /// No description provided for @histMissedCount.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get histMissedCount;

  /// No description provided for @histSkippedCount.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get histSkippedCount;

  /// No description provided for @histPendingCount.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get histPendingCount;

  /// No description provided for @histEmpty.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get histEmpty;

  /// No description provided for @histTotal.
  ///
  /// In en, this message translates to:
  /// **'Total: {count}'**
  String histTotal(int count);

  /// No description provided for @setTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get setTitle;

  /// No description provided for @setLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get setLanguage;

  /// No description provided for @setNotificationSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sound'**
  String get setNotificationSound;

  /// No description provided for @setVoiceReminder.
  ///
  /// In en, this message translates to:
  /// **'Voice reminder'**
  String get setVoiceReminder;

  /// No description provided for @setVoiceOn.
  ///
  /// In en, this message translates to:
  /// **'Speak the reminder aloud'**
  String get setVoiceOn;

  /// No description provided for @setSnoozeDuration.
  ///
  /// In en, this message translates to:
  /// **'Snooze duration'**
  String get setSnoozeDuration;

  /// No description provided for @setGracePeriod.
  ///
  /// In en, this message translates to:
  /// **'Mark missed after'**
  String get setGracePeriod;

  /// No description provided for @setDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get setDarkMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @setAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get setAbout;

  /// No description provided for @setPermissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get setPermissions;

  /// No description provided for @setNotifyPermission.
  ///
  /// In en, this message translates to:
  /// **'Notification permission'**
  String get setNotifyPermission;

  /// No description provided for @setExactAlarm.
  ///
  /// In en, this message translates to:
  /// **'Exact alarm permission'**
  String get setExactAlarm;

  /// No description provided for @setBattery.
  ///
  /// In en, this message translates to:
  /// **'Battery / background'**
  String get setBattery;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get permissionGranted;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Not granted — tap to allow'**
  String get permissionDenied;

  /// No description provided for @setNotifDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow reminders to appear'**
  String get setNotifDesc;

  /// No description provided for @setExactDesc.
  ///
  /// In en, this message translates to:
  /// **'Allow reminders at the exact time'**
  String get setExactDesc;

  /// No description provided for @setBatteryDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep reminders working in the background'**
  String get setBatteryDesc;

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'Medicine Reminder is a reminder and tracking tool only. It does not provide medical advice. Always follow your doctor\'s instructions.'**
  String get aboutBody;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'💊 Medicine Time'**
  String get notifTitle;

  /// No description provided for @notifBody.
  ///
  /// In en, this message translates to:
  /// **'Take {name} — {dose}'**
  String notifBody(String name, String dose);

  /// No description provided for @notifActionTaken.
  ///
  /// In en, this message translates to:
  /// **'TAKEN'**
  String get notifActionTaken;

  /// No description provided for @notifActionSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze {minutes} min'**
  String notifActionSnooze(int minutes);

  /// No description provided for @notifActionSkip.
  ///
  /// In en, this message translates to:
  /// **'SKIP'**
  String get notifActionSkip;

  /// No description provided for @permNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications?'**
  String get permNotifTitle;

  /// No description provided for @permNotifBody.
  ///
  /// In en, this message translates to:
  /// **'Reminders appear as notifications, even when the app is closed. Please allow notifications.'**
  String get permNotifBody;

  /// No description provided for @permExactTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow exact alarms?'**
  String get permExactTitle;

  /// No description provided for @permExactBody.
  ///
  /// In en, this message translates to:
  /// **'For reminders to ring at the exact time, Android needs your permission. The system settings will open — please turn on \"Allow exact alarms\" for this app.'**
  String get permExactBody;

  /// No description provided for @permOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get permOk;

  /// No description provided for @permCancel.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get permCancel;

  /// No description provided for @obWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get obWelcome;

  /// No description provided for @obTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine Reminder'**
  String get obTitle;

  /// No description provided for @obBody.
  ///
  /// In en, this message translates to:
  /// **'I will remind you to take your medicines on time. Setting this up takes just one minute.'**
  String get obBody;

  /// No description provided for @obName.
  ///
  /// In en, this message translates to:
  /// **'What should I call you? (optional)'**
  String get obName;

  /// No description provided for @obNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mom'**
  String get obNameHint;

  /// No description provided for @obStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get obStart;

  /// No description provided for @obSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get obSkip;

  /// No description provided for @voiceTimeToTake.
  ///
  /// In en, this message translates to:
  /// **'It is time to take your medicine. {name}, {dose}.'**
  String voiceTimeToTake(String name, String dose);

  /// No description provided for @voiceTaken.
  ///
  /// In en, this message translates to:
  /// **'Well done! Medicine taken.'**
  String get voiceTaken;

  /// No description provided for @voiceSkipped.
  ///
  /// In en, this message translates to:
  /// **'Medicine skipped.'**
  String get voiceSkipped;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @undoTaken.
  ///
  /// In en, this message translates to:
  /// **'Medicine marked as taken'**
  String get undoTaken;

  /// No description provided for @undoSkipped.
  ///
  /// In en, this message translates to:
  /// **'Medicine skipped'**
  String get undoSkipped;

  /// No description provided for @homeSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Skip this dose?'**
  String get homeSkipConfirmTitle;

  /// No description provided for @homeSkipConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to skip {name}? This will be marked as skipped.'**
  String homeSkipConfirmBody(String name);

  /// No description provided for @btnSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get btnSave;

  /// No description provided for @btnCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get btnCancel;

  /// No description provided for @btnClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get btnClose;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String minutes(int minutes);

  /// No description provided for @speakReminder.
  ///
  /// In en, this message translates to:
  /// **'Speak reminder'**
  String get speakReminder;

  /// No description provided for @missedAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Missed medicine'**
  String get missedAlertTitle;

  /// No description provided for @missedAlertBody.
  ///
  /// In en, this message translates to:
  /// **'{name} at {time} was not taken'**
  String missedAlertBody(String name, String time);

  /// No description provided for @familySync.
  ///
  /// In en, this message translates to:
  /// **'Family & Sync'**
  String get familySync;

  /// No description provided for @familySyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Share medicines and history with family'**
  String get familySyncDesc;

  /// No description provided for @familySyncIntro.
  ///
  /// In en, this message translates to:
  /// **'Family can see whether medicines were taken and get an alert when a dose is missed. Everything stays private to your family.'**
  String get familySyncIntro;

  /// No description provided for @syncRolePrimary.
  ///
  /// In en, this message translates to:
  /// **'I take medicines here'**
  String get syncRolePrimary;

  /// No description provided for @syncRolePrimaryDesc.
  ///
  /// In en, this message translates to:
  /// **'This phone belongs to the person taking medicines'**
  String get syncRolePrimaryDesc;

  /// No description provided for @syncRoleWatcher.
  ///
  /// In en, this message translates to:
  /// **'I am family — I want to help'**
  String get syncRoleWatcher;

  /// No description provided for @syncRoleWatcherDesc.
  ///
  /// In en, this message translates to:
  /// **'Watch over medicines and get missed-dose alerts'**
  String get syncRoleWatcherDesc;

  /// No description provided for @syncCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Family code'**
  String get syncCodeLabel;

  /// No description provided for @syncCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-letter code'**
  String get syncCodeHint;

  /// No description provided for @syncJoin.
  ///
  /// In en, this message translates to:
  /// **'Join family'**
  String get syncJoin;

  /// No description provided for @syncCreate.
  ///
  /// In en, this message translates to:
  /// **'Create family'**
  String get syncCreate;

  /// No description provided for @syncCopied.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get syncCopied;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncOn.
  ///
  /// In en, this message translates to:
  /// **'Sync is on'**
  String get syncOn;

  /// No description provided for @syncOff.
  ///
  /// In en, this message translates to:
  /// **'Sync is off'**
  String get syncOff;

  /// No description provided for @syncLastSync.
  ///
  /// In en, this message translates to:
  /// **'Last synced: {time}'**
  String syncLastSync(String time);

  /// No description provided for @syncNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get syncNever;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @syncDisable.
  ///
  /// In en, this message translates to:
  /// **'Turn off sync'**
  String get syncDisable;

  /// No description provided for @syncDisableConfirm.
  ///
  /// In en, this message translates to:
  /// **'Turning off sync removes this phone from the family. Medicines stay on this phone.'**
  String get syncDisableConfirm;

  /// No description provided for @syncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Cloud sync is not set up for this app yet (add google-services.json). The app works fully offline without it.'**
  String get syncNotConfigured;

  /// No description provided for @missedAlerts.
  ///
  /// In en, this message translates to:
  /// **'Missed-dose alerts'**
  String get missedAlerts;

  /// No description provided for @missedAlertsDesc.
  ///
  /// In en, this message translates to:
  /// **'Get an alert when a medicine is missed'**
  String get missedAlertsDesc;

  /// No description provided for @syncStatusSynced.
  ///
  /// In en, this message translates to:
  /// **'All synced'**
  String get syncStatusSynced;

  /// No description provided for @syncStatusSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncStatusSyncing;

  /// No description provided for @syncPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} changes waiting to sync'**
  String syncPendingCount(int count);

  /// No description provided for @syncRetrying.
  ///
  /// In en, this message translates to:
  /// **'Will retry automatically'**
  String get syncRetrying;

  /// No description provided for @syncCodeShare.
  ///
  /// In en, this message translates to:
  /// **'Share this code with family'**
  String get syncCodeShare;

  /// No description provided for @caregiverTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Dashboard'**
  String get caregiverTitle;

  /// No description provided for @caregiverDesc.
  ///
  /// In en, this message translates to:
  /// **'Weekly adherence and today\'s doses'**
  String get caregiverDesc;

  /// No description provided for @caregiverRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get caregiverRefresh;

  /// No description provided for @caregiverThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get caregiverThisWeek;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
