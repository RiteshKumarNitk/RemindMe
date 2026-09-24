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
  /// **'DoseWise'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get navFamily;

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

  /// No description provided for @homeWellnessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Here is your wellness plan for today.'**
  String get homeWellnessSubtitle;

  /// No description provided for @homeUpcomingDose.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Dose'**
  String get homeUpcomingDose;

  /// No description provided for @homeMarkAsTaken.
  ///
  /// In en, this message translates to:
  /// **'Mark as Taken'**
  String get homeMarkAsTaken;

  /// No description provided for @homeScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Schedule'**
  String get homeScheduleTitle;

  /// No description provided for @homeLogNow.
  ///
  /// In en, this message translates to:
  /// **'Log Now'**
  String get homeLogNow;

  /// No description provided for @homeDailyProgress.
  ///
  /// In en, this message translates to:
  /// **'Today\'s progress'**
  String get homeDailyProgress;

  /// No description provided for @homeProgressOf.
  ///
  /// In en, this message translates to:
  /// **'{taken} of {total} medicines taken'**
  String homeProgressOf(int taken, int total);

  /// No description provided for @homeMissedTitle.
  ///
  /// In en, this message translates to:
  /// **'You missed this medicine'**
  String get homeMissedTitle;

  /// No description provided for @homeMissedBody.
  ///
  /// In en, this message translates to:
  /// **'If you haven\'t taken it yet, follow your normal medication instructions.'**
  String get homeMissedBody;

  /// No description provided for @homeMoreTools.
  ///
  /// In en, this message translates to:
  /// **'More tools'**
  String get homeMoreTools;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first medicine and DoseWise will remind you when it is time to take it.'**
  String get homeEmptyBody;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @errorBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your medicines. Please try again.'**
  String get errorBody;

  /// No description provided for @errorRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get errorRetry;

  /// No description provided for @medConfirmTime.
  ///
  /// In en, this message translates to:
  /// **'Confirm time'**
  String get medConfirmTime;

  /// No description provided for @medOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional details'**
  String get medOptional;

  /// No description provided for @medDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine details'**
  String get medDetailsTitle;

  /// No description provided for @setGroupReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get setGroupReminders;

  /// No description provided for @homeQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get homeQuickActions;

  /// No description provided for @qaWeeklyCalendar.
  ///
  /// In en, this message translates to:
  /// **'Weekly Calendar'**
  String get qaWeeklyCalendar;

  /// No description provided for @qaAdherenceReport.
  ///
  /// In en, this message translates to:
  /// **'Adherence Report'**
  String get qaAdherenceReport;

  /// No description provided for @qaDoctorReport.
  ///
  /// In en, this message translates to:
  /// **'Doctor Report'**
  String get qaDoctorReport;

  /// No description provided for @qaVoiceMode.
  ///
  /// In en, this message translates to:
  /// **'Voice Mode'**
  String get qaVoiceMode;

  /// No description provided for @qaVitalsLog.
  ///
  /// In en, this message translates to:
  /// **'Vitals Log'**
  String get qaVitalsLog;

  /// No description provided for @navMeds.
  ///
  /// In en, this message translates to:
  /// **'Meds'**
  String get navMeds;

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

  /// No description provided for @homeDueNow.
  ///
  /// In en, this message translates to:
  /// **'Due now!'**
  String get homeDueNow;

  /// No description provided for @homeTakeNowBanner.
  ///
  /// In en, this message translates to:
  /// **'Take now!'**
  String get homeTakeNowBanner;

  /// No description provided for @homeTakeNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A dose is due'**
  String get homeTakeNowSubtitle;

  /// No description provided for @alarmTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to take your medicine!'**
  String get alarmTitle;

  /// No description provided for @alarmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} — {dose}'**
  String alarmSubtitle(String name, String dose);

  /// No description provided for @alarmSnooze.
  ///
  /// In en, this message translates to:
  /// **'Snooze'**
  String get alarmSnooze;

  /// No description provided for @alarmLater.
  ///
  /// In en, this message translates to:
  /// **'I\'ll take it later'**
  String get alarmLater;

  /// No description provided for @homeOverdueMin.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min late'**
  String homeOverdueMin(int minutes);

  /// No description provided for @medPresetWeekdays.
  ///
  /// In en, this message translates to:
  /// **'Weekdays'**
  String get medPresetWeekdays;

  /// No description provided for @medPresetWeekends.
  ///
  /// In en, this message translates to:
  /// **'Weekends'**
  String get medPresetWeekends;

  /// No description provided for @medDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get medDuplicate;

  /// No description provided for @medDuplicateHint.
  ///
  /// In en, this message translates to:
  /// **'Create a copy of this medicine'**
  String get medDuplicateHint;

  /// No description provided for @pauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause All Medicines'**
  String get pauseAll;

  /// No description provided for @pauseAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will pause all active medicines and their reminders. You can resume them later.'**
  String get pauseAllConfirm;

  /// No description provided for @resumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume All'**
  String get resumeAll;

  /// No description provided for @homeStreak.
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak! Keep it up! 🎉'**
  String homeStreak(int days);

  /// No description provided for @homeBatchMarkAll.
  ///
  /// In en, this message translates to:
  /// **'Mark all as taken'**
  String get homeBatchMarkAll;

  /// No description provided for @homeAllDoneToday.
  ///
  /// In en, this message translates to:
  /// **'All done for today! 🎉'**
  String get homeAllDoneToday;

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

  /// No description provided for @medSearch.
  ///
  /// In en, this message translates to:
  /// **'Search medicines...'**
  String get medSearch;

  /// No description provided for @medSearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get medSearchClear;

  /// No description provided for @medSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No medicines match your search'**
  String get medSearchEmpty;

  /// No description provided for @medStockTracking.
  ///
  /// In en, this message translates to:
  /// **'Stock tracking (optional)'**
  String get medStockTracking;

  /// No description provided for @medStockCountHint.
  ///
  /// In en, this message translates to:
  /// **'Current pills (e.g. 30)'**
  String get medStockCountHint;

  /// No description provided for @medRefillAtHint.
  ///
  /// In en, this message translates to:
  /// **'Remind at (e.g. 5)'**
  String get medRefillAtHint;

  /// No description provided for @medRefillTitle.
  ///
  /// In en, this message translates to:
  /// **'Time to refill!'**
  String get medRefillTitle;

  /// No description provided for @medRefillBody.
  ///
  /// In en, this message translates to:
  /// **'{name} is running low ({remaining} left). Time to refill.'**
  String medRefillBody(String name, int remaining);

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

  /// No description provided for @histScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get histScheduled;

  /// No description provided for @histActual.
  ///
  /// In en, this message translates to:
  /// **'Actual'**
  String get histActual;

  /// No description provided for @histShowing.
  ///
  /// In en, this message translates to:
  /// **'Showing: {label} ({count})'**
  String histShowing(String label, int count);

  /// No description provided for @medActiveCount.
  ///
  /// In en, this message translates to:
  /// **'{active} of {total} active'**
  String medActiveCount(int active, int total);

  /// No description provided for @medStockLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} left'**
  String medStockLeft(int count);

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

  /// No description provided for @histExport.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get histExport;

  /// No description provided for @medConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule conflict'**
  String get medConflictTitle;

  /// No description provided for @medConflictBody.
  ///
  /// In en, this message translates to:
  /// **'These medicines are already scheduled at the same time: {names}. Continue anyway?'**
  String medConflictBody(String names);

  /// No description provided for @histTrendGood.
  ///
  /// In en, this message translates to:
  /// **'Adherence is looking good!'**
  String get histTrendGood;

  /// No description provided for @histTrendNeedsWork.
  ///
  /// In en, this message translates to:
  /// **'Adherence needs improvement'**
  String get histTrendNeedsWork;

  /// No description provided for @setData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get setData;

  /// No description provided for @setExportJson.
  ///
  /// In en, this message translates to:
  /// **'Export backup'**
  String get setExportJson;

  /// No description provided for @setExportJsonDesc.
  ///
  /// In en, this message translates to:
  /// **'Save all medicines and history as JSON'**
  String get setExportJsonDesc;

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

  /// No description provided for @setAdvanceAlarm.
  ///
  /// In en, this message translates to:
  /// **'Advance alarm'**
  String get setAdvanceAlarm;

  /// No description provided for @setAdvanceAlarmDesc.
  ///
  /// In en, this message translates to:
  /// **'Start alarm sound before dose time'**
  String get setAdvanceAlarmDesc;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @testNotification.
  ///
  /// In en, this message translates to:
  /// **'Test Notification Sound'**
  String get testNotification;

  /// No description provided for @testNotifSent.
  ///
  /// In en, this message translates to:
  /// **'Test notification sent! Check your sound.'**
  String get testNotifSent;

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

  /// No description provided for @setBatteryRestricted.
  ///
  /// In en, this message translates to:
  /// **'Restricted'**
  String get setBatteryRestricted;

  /// No description provided for @setBatteryWarning.
  ///
  /// In en, this message translates to:
  /// **'Optional: on some phones the battery saver can delay reminders. Tap to set DoseWise to \"Unrestricted\".'**
  String get setBatteryWarning;

  /// No description provided for @testNotifFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send a test notification. Open Android settings and allow notifications for DoseWise.'**
  String get testNotifFailed;

  /// No description provided for @setTestScheduled.
  ///
  /// In en, this message translates to:
  /// **'Test a scheduled reminder (1 min)'**
  String get setTestScheduled;

  /// No description provided for @setTestScheduledSent.
  ///
  /// In en, this message translates to:
  /// **'A reminder is set for ~1 minute from now. Close the app and lock your phone — it should ring and vibrate.'**
  String get setTestScheduledSent;

  /// No description provided for @setTestScheduledInexact.
  ///
  /// In en, this message translates to:
  /// **'Set for ~1 minute, but exact alarms are off, so it may be late. Turn on exact alarms for on-time reminders.'**
  String get setTestScheduledInexact;

  /// No description provided for @setTestScheduledFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t schedule the test. Check that notifications are allowed.'**
  String get setTestScheduledFailed;

  /// No description provided for @setScheduledCount.
  ///
  /// In en, this message translates to:
  /// **'Reminders scheduled on this phone: {count}'**
  String setScheduledCount(int count);

  /// No description provided for @aboutBody.
  ///
  /// In en, this message translates to:
  /// **'DoseWise is a reminder and tracking tool only. It does not provide medical advice. Always follow your doctor\'s instructions.'**
  String get aboutBody;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'💊 Medicine Time'**
  String get notifTitle;

  /// No description provided for @notifTitleFor.
  ///
  /// In en, this message translates to:
  /// **'💊 Time for {name}'**
  String notifTitleFor(String name);

  /// No description provided for @notifBody.
  ///
  /// In en, this message translates to:
  /// **'Take {name} — {info}'**
  String notifBody(String name, String info);

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
  /// **'DoseWise'**
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

  /// No description provided for @obBatteryWhy.
  ///
  /// In en, this message translates to:
  /// **'Why is this needed?'**
  String get obBatteryWhy;

  /// No description provided for @obBatteryHow.
  ///
  /// In en, this message translates to:
  /// **'Open your phone\'s Settings, find this app, and turn off \'Battery optimization\' or select \'Unrestricted\'. This keeps reminders working even when the app is closed.'**
  String get obBatteryHow;

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

  /// No description provided for @voiceSnoozed.
  ///
  /// In en, this message translates to:
  /// **'Reminder snoozed.'**
  String get voiceSnoozed;

  /// No description provided for @homeSnoozedUntil.
  ///
  /// In en, this message translates to:
  /// **'Snoozed to {time}'**
  String homeSnoozedUntil(String time);

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

  /// No description provided for @syncSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Create a code so family can help with your medicines — and enter a family member\'s code to help with theirs. You can do both.'**
  String get syncSetupHint;

  /// No description provided for @syncCreateCode.
  ///
  /// In en, this message translates to:
  /// **'Create my family code'**
  String get syncCreateCode;

  /// No description provided for @syncHaveCode.
  ///
  /// In en, this message translates to:
  /// **'I have a family code'**
  String get syncHaveCode;

  /// No description provided for @syncJoinAnother.
  ///
  /// In en, this message translates to:
  /// **'Join another family code'**
  String get syncJoinAnother;

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

  /// No description provided for @syncPrimaryHint.
  ///
  /// In en, this message translates to:
  /// **'On the patient\'s phone, open Family Sync and tap \"I take medicines here\" to get this code.'**
  String get syncPrimaryHint;

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

  /// No description provided for @syncErrorPermission.
  ///
  /// In en, this message translates to:
  /// **'The cloud database rejected the request. This Firebase project\'s Firestore security rules haven\'t been set up — deploy firestore.rules or paste them into Firebase Console → Firestore → Rules.'**
  String get syncErrorPermission;

  /// No description provided for @syncErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your internet connection and try again.'**
  String get syncErrorNetwork;

  /// No description provided for @syncErrorAuth.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was rejected. In the Firebase console, enable Anonymous and Google sign-in, and register this app\'s SHA-1.'**
  String get syncErrorAuth;

  /// No description provided for @syncErrorDetail.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get syncErrorDetail;

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

  /// No description provided for @notifDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Notification Diagnostics'**
  String get notifDiagnostics;

  /// No description provided for @notifFixAll.
  ///
  /// In en, this message translates to:
  /// **'Fix All'**
  String get notifFixAll;

  /// No description provided for @notifStatusOk.
  ///
  /// In en, this message translates to:
  /// **'All permissions are set correctly'**
  String get notifStatusOk;

  /// No description provided for @notifStatusNeedsFix.
  ///
  /// In en, this message translates to:
  /// **'Some settings may prevent reminders from working'**
  String get notifStatusNeedsFix;

  /// No description provided for @notifOpenSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'Open System Settings'**
  String get notifOpenSystemSettings;

  /// No description provided for @syncGoogleSignIn.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get syncGoogleSignIn;

  /// No description provided for @syncSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get syncSignOut;

  /// No description provided for @syncSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please check your internet connection and try again.'**
  String get syncSignInFailed;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your medicines with family members, or use the app offline.'**
  String get loginSubtitle;

  /// No description provided for @loginWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get loginWithGoogle;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginOr;

  /// No description provided for @loginSkip.
  ///
  /// In en, this message translates to:
  /// **'Use Offline'**
  String get loginSkip;

  /// No description provided for @loginOfflineNote.
  ///
  /// In en, this message translates to:
  /// **'You can always sign in later from Settings.'**
  String get loginOfflineNote;

  /// No description provided for @familySyncNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured. Family sync requires Firebase setup. The app works fully offline without it.'**
  String get familySyncNotConfigured;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get profilePersonalInfo;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get profileAge;

  /// No description provided for @profileAgeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 65'**
  String get profileAgeHint;

  /// No description provided for @profileEditInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Information'**
  String get profileEditInfo;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileSaved;

  /// No description provided for @profileSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get profileSignOut;

  /// No description provided for @profileSignOutDesc.
  ///
  /// In en, this message translates to:
  /// **'Sign out of your Google account'**
  String get profileSignOutDesc;

  /// No description provided for @profileSignOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out? Your data stays on this phone.'**
  String get profileSignOutConfirm;

  /// No description provided for @profileSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out successfully'**
  String get profileSignedOut;

  /// No description provided for @profileDangerZone.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get profileDangerZone;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account & data'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountDesc.
  ///
  /// In en, this message translates to:
  /// **'Permanently erase everything on this device, and your account if signed in'**
  String get profileDeleteAccountDesc;

  /// No description provided for @profileDeleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get profileDeleteAccountConfirmTitle;

  /// No description provided for @profileDeleteAccountConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes every medicine, dose and history entry stored on this device. This cannot be undone.'**
  String get profileDeleteAccountConfirmBody;

  /// No description provided for @profileDeleteAccountConfirmBodySignedIn.
  ///
  /// In en, this message translates to:
  /// **'It will also delete your signed-in account and remove you from any family you\'ve joined.'**
  String get profileDeleteAccountConfirmBodySignedIn;

  /// No description provided for @profileDeleteAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get profileDeleteAccountButton;

  /// No description provided for @profileDeleteAccountReauthTitle.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again'**
  String get profileDeleteAccountReauthTitle;

  /// No description provided for @profileDeleteAccountReauthBody.
  ///
  /// In en, this message translates to:
  /// **'For your security, deleting your account needs a recent sign-in. Sign in again, then try again.'**
  String get profileDeleteAccountReauthBody;

  /// No description provided for @profileDeleteAccountReauthButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in again'**
  String get profileDeleteAccountReauthButton;

  /// No description provided for @profileDeleteAccountDone.
  ///
  /// In en, this message translates to:
  /// **'Everything has been deleted.'**
  String get profileDeleteAccountDone;

  /// No description provided for @profileDeleteAccountPartial.
  ///
  /// In en, this message translates to:
  /// **'Your data on this device was deleted. Some account cleanup couldn\'t finish — you can try again later while online.'**
  String get profileDeleteAccountPartial;

  /// No description provided for @profileDeleteAccountOwnerNote.
  ///
  /// In en, this message translates to:
  /// **'You created a family household, so a small amount of membership info stays until another member removes it.'**
  String get profileDeleteAccountOwnerNote;

  /// No description provided for @profileSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google to sync your medicines with family members across devices.'**
  String get profileSignInPrompt;

  /// No description provided for @profileWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back!'**
  String get profileWelcomeBack;

  /// No description provided for @profileSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in with Google'**
  String get profileSignedIn;

  /// No description provided for @profileOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get profileOfflineMode;

  /// No description provided for @profileGuestUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get profileGuestUser;

  /// No description provided for @profileNoName.
  ///
  /// In en, this message translates to:
  /// **'No name set'**
  String get profileNoName;

  /// No description provided for @profileNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileNoInfoYet.
  ///
  /// In en, this message translates to:
  /// **'No personal information yet. Tap \"Edit Information\" to add your name and age.'**
  String get profileNoInfoYet;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @elapsedJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get elapsedJustNow;

  /// No description provided for @elapsedMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String elapsedMinAgo(int minutes);

  /// No description provided for @elapsedHourMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m ago'**
  String elapsedHourMinAgo(int hours, int minutes);

  /// No description provided for @hcCareSection.
  ///
  /// In en, this message translates to:
  /// **'Care'**
  String get hcCareSection;

  /// No description provided for @hcFindTitle.
  ///
  /// In en, this message translates to:
  /// **'Find healthcare'**
  String get hcFindTitle;

  /// No description provided for @hcFindSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search clinics, hospitals and doctors'**
  String get hcFindSubtitle;

  /// No description provided for @hcUpcomingAppointment.
  ///
  /// In en, this message translates to:
  /// **'Upcoming appointment'**
  String get hcUpcomingAppointment;

  /// No description provided for @hcNoUpcomingAppointment.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointment'**
  String get hcNoUpcomingAppointment;

  /// No description provided for @hcViewAllAppointments.
  ///
  /// In en, this message translates to:
  /// **'My appointments'**
  String get hcViewAllAppointments;

  /// No description provided for @hcSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Clinic, hospital or doctor'**
  String get hcSearchHint;

  /// No description provided for @hcSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get hcSearchAction;

  /// No description provided for @hcAllTypes.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get hcAllTypes;

  /// No description provided for @hcFilterType.
  ///
  /// In en, this message translates to:
  /// **'Provider type'**
  String get hcFilterType;

  /// No description provided for @hcTypeHospital.
  ///
  /// In en, this message translates to:
  /// **'Hospitals'**
  String get hcTypeHospital;

  /// No description provided for @hcTypeClinic.
  ///
  /// In en, this message translates to:
  /// **'Clinics'**
  String get hcTypeClinic;

  /// No description provided for @hcTypePolyclinic.
  ///
  /// In en, this message translates to:
  /// **'Polyclinics'**
  String get hcTypePolyclinic;

  /// No description provided for @hcTypeDiagnostic.
  ///
  /// In en, this message translates to:
  /// **'Diagnostic centres'**
  String get hcTypeDiagnostic;

  /// No description provided for @hcTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other providers'**
  String get hcTypeOther;

  /// No description provided for @hcProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinics & hospitals'**
  String get hcProvidersTitle;

  /// No description provided for @hcDoctorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get hcDoctorsTitle;

  /// No description provided for @hcSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No healthcare providers found'**
  String get hcSearchEmptyTitle;

  /// No description provided for @hcSearchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different name, provider type or city.'**
  String get hcSearchEmptyBody;

  /// No description provided for @hcNoDoctorsTitle.
  ///
  /// In en, this message translates to:
  /// **'No doctors listed'**
  String get hcNoDoctorsTitle;

  /// No description provided for @hcNoDoctorsBody.
  ///
  /// In en, this message translates to:
  /// **'This provider has not published any bookable doctors yet.'**
  String get hcNoDoctorsBody;

  /// No description provided for @hcNoDoctorsShort.
  ///
  /// In en, this message translates to:
  /// **'No doctors listed'**
  String get hcNoDoctorsShort;

  /// No description provided for @hcLoadFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load this'**
  String get hcLoadFailedTitle;

  /// No description provided for @hcLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get hcLoadFailedBody;

  /// No description provided for @hcOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'You are offline'**
  String get hcOfflineTitle;

  /// No description provided for @hcRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get hcRetry;

  /// No description provided for @hcLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get hcLoadMore;

  /// No description provided for @hcVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get hcVerified;

  /// No description provided for @hcDoctorCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No doctors listed} =1{1 doctor} other{{count} doctors}}'**
  String hcDoctorCount(int count);

  /// No description provided for @hcAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get hcAbout;

  /// No description provided for @hcContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get hcContact;

  /// No description provided for @hcLocations.
  ///
  /// In en, this message translates to:
  /// **'Locations'**
  String get hcLocations;

  /// No description provided for @hcCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get hcCall;

  /// No description provided for @hcEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get hcEmail;

  /// No description provided for @hcWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get hcWebsite;

  /// No description provided for @hcBookAppointment.
  ///
  /// In en, this message translates to:
  /// **'Book appointment'**
  String get hcBookAppointment;

  /// No description provided for @hcChooseBranchTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a branch'**
  String get hcChooseBranchTitle;

  /// No description provided for @hcChooseBranchBody.
  ///
  /// In en, this message translates to:
  /// **'This provider has more than one location. Pick the one you are visiting.'**
  String get hcChooseBranchBody;

  /// No description provided for @hcBranch.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get hcBranch;

  /// No description provided for @hcSpecialty.
  ///
  /// In en, this message translates to:
  /// **'Speciality'**
  String get hcSpecialty;

  /// No description provided for @hcQualifications.
  ///
  /// In en, this message translates to:
  /// **'Qualifications'**
  String get hcQualifications;

  /// No description provided for @hcExperience.
  ///
  /// In en, this message translates to:
  /// **'{years, plural, =1{1 year experience} other{{years} years experience}}'**
  String hcExperience(int years);

  /// No description provided for @hcLanguages.
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get hcLanguages;

  /// No description provided for @hcConsultationFee.
  ///
  /// In en, this message translates to:
  /// **'{fee} per visit'**
  String hcConsultationFee(String fee);

  /// No description provided for @hcRegistration.
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get hcRegistration;

  /// No description provided for @hcSelectDateTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get hcSelectDateTitle;

  /// No description provided for @hcSelectTimeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get hcSelectTimeTitle;

  /// No description provided for @hcClinicTimeNote.
  ///
  /// In en, this message translates to:
  /// **'Times are in the clinic\'s time zone ({zone}).'**
  String hcClinicTimeNote(String zone);

  /// No description provided for @hcNoSlotsTitle.
  ///
  /// In en, this message translates to:
  /// **'No available appointments'**
  String get hcNoSlotsTitle;

  /// No description provided for @hcNoSlotsBody.
  ///
  /// In en, this message translates to:
  /// **'There are no free times on this day. Try another date.'**
  String get hcNoSlotsBody;

  /// No description provided for @hcSlotsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t check this day. Please try again.'**
  String get hcSlotsLoadFailed;

  /// No description provided for @hcContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get hcContinue;

  /// No description provided for @hcYourDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your details'**
  String get hcYourDetailsTitle;

  /// No description provided for @hcYourDetailsBody.
  ///
  /// In en, this message translates to:
  /// **'The clinic registers you as a patient with these details.'**
  String get hcYourDetailsBody;

  /// No description provided for @hcFirstName.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get hcFirstName;

  /// No description provided for @hcLastName.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get hcLastName;

  /// No description provided for @hcPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get hcPhone;

  /// No description provided for @hcOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get hcOptional;

  /// No description provided for @hcReasonTitle.
  ///
  /// In en, this message translates to:
  /// **'Reason for visit'**
  String get hcReasonTitle;

  /// No description provided for @hcReasonHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. fever since two days'**
  String get hcReasonHint;

  /// No description provided for @hcReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Check and confirm'**
  String get hcReviewTitle;

  /// No description provided for @hcConfirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm appointment'**
  String get hcConfirmBooking;

  /// No description provided for @hcBookingConfirmedTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointment confirmed'**
  String get hcBookingConfirmedTitle;

  /// No description provided for @hcBookingRequestedTitle.
  ///
  /// In en, this message translates to:
  /// **'Appointment requested'**
  String get hcBookingRequestedTitle;

  /// No description provided for @hcBookingPendingBody.
  ///
  /// In en, this message translates to:
  /// **'The clinic will confirm your appointment. You can follow it in My appointments.'**
  String get hcBookingPendingBody;

  /// No description provided for @hcBookingReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get hcBookingReferenceLabel;

  /// No description provided for @hcViewAppointment.
  ///
  /// In en, this message translates to:
  /// **'View appointment'**
  String get hcViewAppointment;

  /// No description provided for @hcDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get hcDone;

  /// No description provided for @hcSlotTakenTitle.
  ///
  /// In en, this message translates to:
  /// **'That time was just taken'**
  String get hcSlotTakenTitle;

  /// No description provided for @hcSlotTakenBody.
  ///
  /// In en, this message translates to:
  /// **'Someone else booked it first. Please choose another time.'**
  String get hcSlotTakenBody;

  /// No description provided for @hcFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This is needed.'**
  String get hcFieldRequired;

  /// No description provided for @hcEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get hcEmailInvalid;

  /// No description provided for @hcPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 10 characters.'**
  String get hcPasswordTooShort;

  /// No description provided for @hcBookingFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t book this appointment'**
  String get hcBookingFailedTitle;

  /// No description provided for @hcBookingFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Nothing was booked. You can try again or pick another time.'**
  String get hcBookingFailedBody;

  /// No description provided for @hcMyAppointments.
  ///
  /// In en, this message translates to:
  /// **'My appointments'**
  String get hcMyAppointments;

  /// No description provided for @hcTabUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get hcTabUpcoming;

  /// No description provided for @hcTabPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get hcTabPast;

  /// No description provided for @hcTabCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get hcTabCancelled;

  /// No description provided for @hcNoUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments'**
  String get hcNoUpcomingTitle;

  /// No description provided for @hcNoUpcomingBody.
  ///
  /// In en, this message translates to:
  /// **'Find a clinic, choose a doctor and book a visit — it will appear here.'**
  String get hcNoUpcomingBody;

  /// No description provided for @hcNoPastTitle.
  ///
  /// In en, this message translates to:
  /// **'No past appointments'**
  String get hcNoPastTitle;

  /// No description provided for @hcNoPastBody.
  ///
  /// In en, this message translates to:
  /// **'Visits you complete will show up here.'**
  String get hcNoPastBody;

  /// No description provided for @hcNoCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing cancelled'**
  String get hcNoCancelledTitle;

  /// No description provided for @hcNoCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'Appointments you cancel will be listed here.'**
  String get hcNoCancelledBody;

  /// No description provided for @hcAppointmentsSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to see your appointments'**
  String get hcAppointmentsSignInTitle;

  /// No description provided for @hcAppointmentsSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Your appointments are stored in your clinic account.'**
  String get hcAppointmentsSignInBody;

  /// No description provided for @hcStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get hcStatusRequested;

  /// No description provided for @hcStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get hcStatusConfirmed;

  /// No description provided for @hcStatusCheckedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get hcStatusCheckedIn;

  /// No description provided for @hcStatusWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get hcStatusWaiting;

  /// No description provided for @hcStatusInConsultation.
  ///
  /// In en, this message translates to:
  /// **'In consultation'**
  String get hcStatusInConsultation;

  /// No description provided for @hcStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get hcStatusCompleted;

  /// No description provided for @hcStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get hcStatusCancelled;

  /// No description provided for @hcStatusNoShow.
  ///
  /// In en, this message translates to:
  /// **'Missed'**
  String get hcStatusNoShow;

  /// No description provided for @hcStatusRescheduled.
  ///
  /// In en, this message translates to:
  /// **'Rescheduled'**
  String get hcStatusRescheduled;

  /// No description provided for @hcStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get hcStatusUnknown;

  /// No description provided for @hcWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get hcWhen;

  /// No description provided for @hcWhere.
  ///
  /// In en, this message translates to:
  /// **'Where'**
  String get hcWhere;

  /// No description provided for @hcDoctorLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get hcDoctorLabel;

  /// No description provided for @hcReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get hcReasonLabel;

  /// No description provided for @hcNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get hcNotesLabel;

  /// No description provided for @hcCancelAppointment.
  ///
  /// In en, this message translates to:
  /// **'Cancel appointment'**
  String get hcCancelAppointment;

  /// No description provided for @hcKeepAppointment.
  ///
  /// In en, this message translates to:
  /// **'Keep appointment'**
  String get hcKeepAppointment;

  /// No description provided for @hcCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this appointment?'**
  String get hcCancelConfirmTitle;

  /// No description provided for @hcCancelReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get hcCancelReasonHint;

  /// No description provided for @hcAppointmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment cancelled'**
  String get hcAppointmentCancelled;

  /// No description provided for @hcRescheduleAction.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get hcRescheduleAction;

  /// No description provided for @hcRescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a new time'**
  String get hcRescheduleTitle;

  /// No description provided for @hcRescheduledMessage.
  ///
  /// In en, this message translates to:
  /// **'Appointment moved'**
  String get hcRescheduledMessage;

  /// No description provided for @hcSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has ended. Please sign in again.'**
  String get hcSessionExpired;

  /// No description provided for @hcQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Your queue'**
  String get hcQueueTitle;

  /// No description provided for @hcQueueToken.
  ///
  /// In en, this message translates to:
  /// **'Token {token}'**
  String hcQueueToken(int token);

  /// No description provided for @hcQueueAhead.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 patient ahead of you} other{{count} patients ahead of you}}'**
  String hcQueueAhead(int count);

  /// No description provided for @hcQueueYouAreNext.
  ///
  /// In en, this message translates to:
  /// **'You are next in line'**
  String get hcQueueYouAreNext;

  /// No description provided for @hcQueueCheckInNote.
  ///
  /// In en, this message translates to:
  /// **'Please check in at the clinic reception when you arrive. Your token appears here once they add you to the queue.'**
  String get hcQueueCheckInNote;

  /// No description provided for @hcQueueCalled.
  ///
  /// In en, this message translates to:
  /// **'Please go to the doctor\'s room'**
  String get hcQueueCalled;

  /// No description provided for @hcQueueInConsultation.
  ///
  /// In en, this message translates to:
  /// **'You are with the doctor now'**
  String get hcQueueInConsultation;

  /// No description provided for @hcQueueFinished.
  ///
  /// In en, this message translates to:
  /// **'This visit is finished'**
  String get hcQueueFinished;

  /// No description provided for @hcSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to book'**
  String get hcSignInTitle;

  /// No description provided for @hcSignInBody.
  ///
  /// In en, this message translates to:
  /// **'Booking uses your clinic account — the same email and password you use on the clinic website.'**
  String get hcSignInBody;

  /// No description provided for @hcSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get hcSignIn;

  /// No description provided for @hcSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get hcSignOut;

  /// No description provided for @hcEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get hcEmailLabel;

  /// No description provided for @hcPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get hcPasswordLabel;

  /// No description provided for @hcFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get hcFullNameLabel;

  /// No description provided for @hcCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get hcCreateAccount;

  /// No description provided for @hcHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get hcHaveAccount;

  /// No description provided for @hcNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get hcNoAccount;

  /// No description provided for @hcSignedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String hcSignedInAs(String name);

  /// No description provided for @hcSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t sign you in. Check your email and password.'**
  String get hcSignInFailed;

  /// No description provided for @hcApiSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clinic server (QA)'**
  String get hcApiSettingsTitle;

  /// No description provided for @hcApiSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Base address of the clinic platform API'**
  String get hcApiSettingsHint;

  /// No description provided for @hcApiSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Server address saved'**
  String get hcApiSettingsSaved;

  /// No description provided for @hcApiSettingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get hcApiSettingsReset;

  /// No description provided for @hcFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get hcFiltersTitle;

  /// No description provided for @hcCityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get hcCityLabel;

  /// No description provided for @hcCityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Jaipur'**
  String get hcCityHint;

  /// No description provided for @hcApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get hcApply;

  /// No description provided for @hcClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get hcClear;

  /// No description provided for @hcRelInMinutes.
  ///
  /// In en, this message translates to:
  /// **'In {minutes} min'**
  String hcRelInMinutes(int minutes);

  /// No description provided for @hcRelInHours.
  ///
  /// In en, this message translates to:
  /// **'In {hours} h'**
  String hcRelInHours(int hours);

  /// No description provided for @hcRelStartingSoon.
  ///
  /// In en, this message translates to:
  /// **'Starting soon'**
  String get hcRelStartingSoon;

  /// No description provided for @hcRelToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get hcRelToday;

  /// No description provided for @hcRelTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get hcRelTomorrow;

  /// No description provided for @hcTimeUnknown.
  ///
  /// In en, this message translates to:
  /// **'Time to be confirmed'**
  String get hcTimeUnknown;

  /// No description provided for @hcUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'This provider is no longer listed'**
  String get hcUnavailableTitle;

  /// No description provided for @hcUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'It may have been unpublished. Go back and choose another provider.'**
  String get hcUnavailableBody;
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
