import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/localization/l10n_helper.dart';
import '../core/notifications/notification_service.dart';
import '../services/home_widget_service.dart';
import '../core/notifications/reminder_text.dart';
import '../core/utilities/date_utils.dart';
import '../data/models/adherence_stats.dart';
import '../data/models/dose_entry.dart';
import '../data/models/dose_status.dart';
import '../data/models/medicine.dart';
import '../data/repositories/dose_repository.dart';
import '../data/repositories/medicine_repository.dart';
import '../services/dose_action_handler.dart';
import '../services/dose_scheduler.dart';
import '../services/settings_controller.dart';
import '../services/sync/sync_service.dart';
import '../services/voice_service.dart';

/// The single application controller: owns the repositories and services and
/// exposes the data the screens render. All mutating flows funnel through
/// here so the UI always sees a consistent, refreshed state.
class AppState extends ChangeNotifier {
  AppState({
    required this.medicineRepository,
    required this.doseRepository,
    required this.settings,
    required this.notifications,
    required this.doseScheduler,
    required this.actionHandler,
    required this.voice,
    required this.sync,
  });

  final MedicineRepository medicineRepository;
  final DoseRepository doseRepository;
  final SettingsController settings;
  final NotificationService notifications;
  final DoseScheduler doseScheduler;
  final DoseActionHandler actionHandler;
  final VoiceService voice;
  final SyncService sync;

  bool _loading = true;
  List<DoseEntry> _todayDoses = const [];
  List<Medicine> _medicines = const [];
  DoseEntry? _nextDose;
  AdherenceStats _todayStats = const AdherenceStats();
  bool _notificationsEnabled = true;
  bool _exactAlarmsEnabled = true;
  bool _batteryUnrestricted = true;
  int _revision = 0;

  // Undo support: stores the last dose action so it can be reversed.
  DoseEntry? _lastActionEntry;
  DoseStatus? _lastActionPreviousStatus;
  DateTime? _lastActionPreviousTakenAt;
  DateTime? _lastActionPreviousSkippedAt;

  bool get loading => _loading;
  List<DoseEntry> get todayDoses => _todayDoses;
  List<Medicine> get medicines => _medicines;
  DoseEntry? get nextDose => _nextDose;
  AdherenceStats get todayStats => _todayStats;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get exactAlarmsEnabled => _exactAlarmsEnabled;

  /// False when the OS is battery-restricting the app — Doze can then delay or
  /// drop scheduled dose alarms. Surfaced as a warning in Settings.
  bool get batteryUnrestricted => _batteryUnrestricted;

  /// Incremented on every data refresh; lets screens detect that the data
  /// changed (e.g. after a notification action).
  int get revision => _revision;

  /// [deferScheduleSync] (used by `main()`) shows the UI from local data
  /// immediately and runs the full refresh — which reconciles every OS
  /// notification, dozens of slow platform calls — in the background, so it
  /// can never hang the splash screen. Left false everywhere else (and in
  /// tests) so callers can await a fully-settled state.
  Future<void> init({bool deferScheduleSync = false}) async {
    await refreshPermissionStatus();
    if (!deferScheduleSync) {
      await refresh();
      return;
    }
    final now = DateTime.now();
    final grace = settings.graceDuration;
    await doseRepository.sweepMissed(grace, now);
    await _reloadTodayData(now, grace);
    _loading = false;
    _revision++;
    notifyListeners();
    unawaited(refresh());
  }

  /// Refreshes permission flags without showing any system dialog.
  Future<void> refreshPermissionStatus() async {
    _notificationsEnabled = await notifications.areNotificationsEnabled();
    _exactAlarmsEnabled = await notifications.canScheduleExact();
    _batteryUnrestricted = await notifications.isIgnoringBatteryOptimizations();
    notifyListeners();
  }

  Future<void> _reloadTodayData(DateTime now, Duration grace) async {
    final start = AppDateUtils.startOfDay(now);
    final end = start.add(const Duration(days: 1));
    _todayDoses = await doseRepository.getEntriesBetween(start, end);
    _todayStats = await doseRepository.statsBetween(
      start,
      end,
      grace: grace,
      now: now,
    );
    _medicines = await medicineRepository.getAll();
    _nextDose = _computeNext(_todayDoses, grace, now);
  }

  /// Reloads missed sweeps + today's data, then reconciles every OS
  /// notification. Callers that block the UI on this (resume, after a save)
  /// accept the latency; `init()` does not — it runs this in the background.
  Future<void> refresh() async {
    final now = DateTime.now();
    final grace = settings.graceDuration;

    await doseRepository.sweepMissed(grace, now);
    await doseScheduler.sync(
      now: now,
      days: AppConstants.windowDays,
      exact: _exactAlarmsEnabled,
      text: ReminderText.from(
        settings.settings.locale,
        snoozeMinutes: settings.snoozeMinutes,
      ),
      advanceMinutes: settings.advanceMinutes,
    );
    await _reloadTodayData(now, grace);
    _checkRefillReminders();
    HomeWidgetService.update(
      todayDoses: _todayDoses,
      now: now,
      locale: settings.settings.locale,
    );
    _loading = false;
    _revision++;
    notifyListeners();
  }

  // ---- Refill reminders -----------------------------------------------------

  void _checkRefillReminders() {
    for (final med in _medicines) {
      if (!med.active ||
          !med.hasStockTracking ||
          med.stockCount == null ||
          med.refillAt == null) {
        continue;
      }
      if (med.stockCount! <= med.refillAt!) {
        final l10n = l10nFor(settings.settings.locale);
        notifications.showRefillAlert(
          title: l10n.medRefillTitle,
          body: l10n.medRefillBody(med.name, med.stockCount!),
        );
      }
    }
  }

  // ---- Dose actions ---------------------------------------------------------

  /// Saves the dose's current state so it can be undone.
  void _saveUndoState(DoseEntry entry) {
    _lastActionEntry = entry;
    _lastActionPreviousStatus = entry.dose.status;
    _lastActionPreviousTakenAt = entry.dose.takenAt;
    _lastActionPreviousSkippedAt = entry.dose.skippedAt;
  }

  /// Reverts the last markTaken / markSkipped action.
  Future<void> undoLastAction() async {
    final entry = _lastActionEntry;
    final prevStatus = _lastActionPreviousStatus;
    if (entry == null || prevStatus == null) return;
    await doseRepository.restorePreviousStatus(
      entry.dose.id!,
      status: prevStatus,
      takenAt: _lastActionPreviousTakenAt,
      skippedAt: _lastActionPreviousSkippedAt,
    );
    _lastActionEntry = null;
    _lastActionPreviousStatus = null;
    await refresh();
    unawaited(sync.syncNow());
  }

  bool get canUndo => _lastActionEntry != null;

  Future<void> markTaken(DoseEntry entry) async {
    _saveUndoState(entry);
    await doseRepository.markTaken(entry.dose.id!, DateTime.now());
    await notifications.cancel(entry.dose.id!);
    if (settings.voiceEnabled) {
      final l10n = l10nFor(settings.settings.locale);
      await voice.speak(l10n.voiceTaken, settings.settings.locale);
    }
    await refresh();
    unawaited(sync.syncNow());
  }

  Future<void> markSkipped(DoseEntry entry) async {
    _saveUndoState(entry);
    await doseRepository.markSkipped(entry.dose.id!, DateTime.now());
    await notifications.cancel(entry.dose.id!);
    if (settings.voiceEnabled) {
      final l10n = l10nFor(settings.settings.locale);
      await voice.speak(l10n.voiceSkipped, settings.settings.locale);
    }
    await refresh();
    unawaited(sync.syncNow());
  }

  /// Entry point for notification taps / action buttons, both from the live
  /// callback and from a cold start.
  Future<void> handleNotificationTap({
    String? actionId,
    String? payload,
  }) async {
    await actionHandler.handle(actionId: actionId, payload: payload);
    await refresh();
  }

  /// History data for a time range (used by the History screen).
  Future<(List<DoseEntry>, AdherenceStats)> historyFor(
    DateTime start,
    DateTime end,
  ) async {
    final now = DateTime.now();
    final entries = await doseRepository.getEntriesBetween(start, end);
    final stats = await doseRepository.statsBetween(
      start,
      end,
      grace: settings.graceDuration,
      now: now,
    );
    return (entries, stats);
  }

  // ---- Medicine management ----------------------------------------------------

  Future<void> saveMedicine(Medicine medicine) async {
    if (medicine.id == null) {
      await medicineRepository.insert(medicine);
    } else {
      await medicineRepository.update(medicine);
      // Stale pending doses are dropped so they regenerate with the new
      // schedule/name; their old notifications are cancelled by the sync.
      await doseRepository.deletePendingFrom(
        medicine.id!,
        AppDateUtils.startOfDay(DateTime.now()),
      );
    }
    await refresh();
    unawaited(sync.syncNow());
  }

  Future<void> setMedicineActive(int id, bool active) async {
    await medicineRepository.setActive(id, active);
    if (!active) {
      await doseRepository.deletePendingFrom(
        id,
        AppDateUtils.startOfDay(DateTime.now()),
      );
    }
    await refresh();
    unawaited(sync.syncNow());
  }

  Future<void> deleteMedicine(int id) async {
    await doseRepository.deleteForMedicine(id);
    await medicineRepository.delete(id);
    await refresh();
    // Record the deletion so the cloud removes it on other phones too.
    unawaited(sync.tombstoneMedicine(id));
  }

  // ---- Permission flows ------------------------------------------------------

  /// Prompts for POST_NOTIFICATIONS and, on Android 12+, exact alarms.
  /// Returns after both are attempted.
  Future<void> requestAllPermissions() async {
    await notifications.requestPermission();
    await refreshPermissionStatus();
  }

  Future<void> requestExactAlarms() async {
    await notifications.requestExactAlarmPermission();
    await refreshPermissionStatus();
  }

  // ---- Helpers ----------------------------------------------------------------

  DoseEntry? _computeNext(
    List<DoseEntry> entries,
    Duration grace,
    DateTime now,
  ) {
    final pending =
        entries
            .where((e) => e.effectiveStatus(grace, now) == DoseStatus.pending)
            .toList()
          ..sort((a, b) => a.dose.scheduledAt.compareTo(b.dose.scheduledAt));
    if (pending.isEmpty) return null;
    // A dose that is due now (or up to 10 minutes late) takes priority.
    for (final e in pending) {
      if (!e.dose.scheduledAt.isAfter(now.add(const Duration(minutes: 10)))) {
        return e;
      }
    }
    return pending.first;
  }
}
