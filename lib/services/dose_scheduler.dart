import '../core/notifications/notification_service.dart';
import '../core/notifications/reminder_text.dart';
import '../data/models/dose_status.dart';
import '../data/models/medicine.dart';
import '../data/models/medicine_dose.dart';
import '../data/models/medicine_frequency.dart';
import '../data/models/medicine_schedule.dart';
import '../data/repositories/dose_repository.dart';
import '../data/repositories/medicine_repository.dart';

/// Makes sure doses exist for the upcoming window and that the OS has exactly
/// the right notifications scheduled for them.
class DoseScheduler {
  DoseScheduler({
    required this.medicineRepository,
    required this.doseRepository,
    required this.scheduler,
  });

  final MedicineRepository medicineRepository;
  final DoseRepository doseRepository;
  final ReminderScheduler scheduler;

  /// Reconciles scheduled notifications with the desired state:
  ///  - creates any missing dose rows for the window (today .. +days),
  ///  - schedules notifications for pending future doses,
  ///  - cancels notifications whose dose no longer needs one (edited,
  ///    paused, deleted, taken from the app).
  ///
  /// Pre-loads existing doses in a single query to avoid N+1 DB calls
  /// (was one SELECT per medicine × schedule × day before this change).
  Future<void> sync({
    required DateTime now,
    required int days,
    required bool exact,
    required ReminderText text,
  }) async {
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(Duration(days: days));
    final medicines = await medicineRepository.getAll();

    // Pre-load all existing pending doses in the window to avoid
    // individual ensureDose queries for every occurrence.
    final existingDoses = await doseRepository.getPendingBetween(start, end);
    final existingKeys = <String, MedicineDose>{
      for (final d in existingDoses)
        '${d.medicineId}_${d.scheduledAt.toIso8601String()}': d,
    };

    final desired = <int, ({DateTime when, Medicine medicine})>{};
    for (final med in medicines) {
      if (!med.active) continue;
      for (final s in med.schedules.where((s) => s.enabled)) {
        for (final occ in _occurrences(med, s, start, end)) {
          final key = '${med.id}_${occ.toIso8601String()}';
          MedicineDose? dose = existingKeys.remove(key);
          // ignore: prefer_conditional_assignment — ??= doesn't support async
          if (dose == null) {
            // Missing dose: create it (individual insert, but rare path).
            dose = await doseRepository.ensureDose(
              medicineId: med.id!,
              scheduledAt: occ,
            );
          }
          if (dose == null) continue;
          final when = _notificationTime(dose, now);
          if (when != null) {
            desired[dose.id!] = (when: when, medicine: med);
          }
        }
      }
    }

    final pending = await scheduler.pendingIds();
    for (final entry in desired.entries) {
      if (pending.contains(entry.key)) continue;
      final med = entry.value.medicine;
      await scheduler.scheduleDoseReminder(
        doseId: entry.key,
        title: text.title,
        body: text.body(med.name, med.doseLabel),
        when: entry.value.when,
        exact: exact,
        takenLabel: text.takenLabel,
        snoozeLabel: text.snoozeLabel,
        skipLabel: text.skipLabel,
      );
    }
    for (final id in pending) {
      if (!desired.containsKey(id)) {
        await scheduler.cancel(id);
      }
    }
  }

  /// When a notification for this dose should fire, or null when none is
  /// needed (final outcome, or time already past).
  DateTime? _notificationTime(MedicineDose dose, DateTime now) {
    if (dose.status != DoseStatus.pending) return null;
    final snoozed = dose.snoozedUntil;
    if (snoozed != null && snoozed.isAfter(now)) return snoozed;
    if (dose.scheduledAt.isAfter(now)) return dose.scheduledAt;
    return null;
  }

  List<DateTime> _occurrences(
    Medicine med,
    MedicineSchedule s,
    DateTime start,
    DateTime end,
  ) {
    final out = <DateTime>[];
    if (med.frequency == MedicineFrequency.once) {
      final once = med.onceDate;
      if (once == null) return out;
      final dt = DateTime(once.year, once.month, once.day, s.hour, s.minute);
      if (!dt.isBefore(start) && !dt.isAfter(end)) out.add(dt);
      return out;
    }
    var day = start;
    while (!day.isAfter(end)) {
      if (med.frequency == MedicineFrequency.specificDays &&
          !med.selectedDays.contains(day.weekday)) {
        day = day.add(const Duration(days: 1));
        continue;
      }
      final dt = DateTime(day.year, day.month, day.day, s.hour, s.minute);
      if (!dt.isBefore(start) && !dt.isAfter(end)) out.add(dt);
      day = day.add(const Duration(days: 1));
    }
    return out;
  }
}
