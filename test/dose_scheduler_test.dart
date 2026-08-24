import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/core/notifications/reminder_text.dart';
import 'package:medireminder/data/models/medicine_frequency.dart';
import 'package:medireminder/data/models/medicine_schedule.dart';

import 'test_helpers.dart';

void main() {
  // Monday, 9:00 AM local.
  final now = DateTime(2026, 1, 5, 9, 0);

  ReminderText text() => ReminderText.from('en', snoozeMinutes: 10);

  group('DoseScheduler', () {
    test('daily medicine generates a dose and notification per day', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(makeMedicine());

      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );

      // 14 doses (today through +13 days)...
      final entries = await env.doseRepository.getEntriesBetween(
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 19),
      );
      expect(entries.length, 14);

      // ...but today's 8:00 AM is already past, so only 13 notifications.
      expect(env.fakeScheduler.scheduled.length, 13);
      final next = env.fakeScheduler.scheduled.values.toList()..sort();
      expect(next.first, DateTime(2026, 1, 6, 8, 0));
    });

    test('specific days only generate on the selected weekdays', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(
        makeMedicine(
          frequency: MedicineFrequency.specificDays,
          selectedDays: [DateTime.monday, DateTime.wednesday],
        ),
      );

      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );

      final entries = await env.doseRepository.getEntriesBetween(
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 19),
      );
      expect(entries.length, 4); // Mon 5, Wed 7, Mon 12, Wed 14
      for (final e in entries) {
        expect(
          e.dose.scheduledAt.weekday == DateTime.monday ||
              e.dose.scheduledAt.weekday == DateTime.wednesday,
          isTrue,
        );
      }
    });

    test('once medicine schedules a single dose on its date', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(
        makeMedicine(
          frequency: MedicineFrequency.once,
          onceDate: DateTime(2026, 1, 10),
        ),
      );

      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );

      final entries = await env.doseRepository.getEntriesBetween(
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 19),
      );
      expect(entries.length, 1);
      expect(entries.first.dose.scheduledAt, DateTime(2026, 1, 10, 8, 0));
      expect(env.fakeScheduler.scheduled.length, 1);
    });

    test('inactive medicine creates nothing', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(makeMedicine(active: false));

      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );

      expect(env.fakeScheduler.scheduled, isEmpty);
      expect(
        (await env.doseRepository.getEntriesBetween(
          DateTime(2026, 1, 5),
          DateTime(2026, 1, 19),
        )).length,
        0,
      );
    });

    test('multiple times per day schedules each time', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(
        makeMedicine(
          schedules: const [
            MedicineSchedule(medicineId: 0, hour: 8, minute: 0),
            MedicineSchedule(medicineId: 0, hour: 20, minute: 0),
          ],
        ),
      );

      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );

      final entries = await env.doseRepository.getEntriesBetween(
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 19),
      );
      expect(entries.length, 28); // 2 per day
    });

    test('taken dose: notification is cancelled on resync', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(makeMedicine());
      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );
      expect(env.fakeScheduler.scheduled.length, 13);

      // Tomorrow's dose exists; take it (as if via notification action).
      final tomorrow = (await env.doseRepository.getEntriesBetween(
        DateTime(2026, 1, 6),
        DateTime(2026, 1, 7),
      )).first;
      await env.doseRepository.markTaken(
        tomorrow.dose.id!,
        DateTime(2026, 1, 5, 10, 0),
      );

      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );
      expect(
        env.fakeScheduler.scheduled.containsKey(tomorrow.dose.id!),
        isFalse,
      );
      expect(
        env.fakeScheduler.log.contains('cancel:${tomorrow.dose.id}'),
        isTrue,
      );
      expect(env.fakeScheduler.scheduled.length, 12);
    });

    test('snoozed dose is rescheduled at the snooze time', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(makeMedicine());
      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );

      // Today's 8:00 dose (already past) gets snoozed to 9:30.
      final today = (await env.doseRepository.getEntriesBetween(
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 6),
      )).first;
      final snoozeUntil = DateTime(2026, 1, 5, 9, 30);
      await env.doseRepository.setSnoozedUntil(today.dose.id!, snoozeUntil);

      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );
      expect(env.fakeScheduler.scheduled[today.dose.id], snoozeUntil);
    });

    test('edited medicine: stale notifications are cancelled', () async {
      final env = await TestEnv.create();
      await env.medicineRepository.insert(makeMedicine());
      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );
      expect(env.fakeScheduler.scheduled.length, 13);

      // Simulate an edit that removes today's pending doses, then resync.
      final meds = await env.medicineRepository.getAll();
      await env.doseRepository.deletePendingFrom(
        meds.first.id!,
        DateTime(2026, 1, 5),
      );
      await env.doseScheduler.sync(
        now: now,
        days: 14,
        exact: true,
        text: text(),
        advanceMinutes: 0,
      );

      // Today's past dose is regenerated (for history), but the schedule is
      // rebuilt from scratch: 13 future notifications, none left over.
      final entries = await env.doseRepository.getEntriesBetween(
        DateTime(2026, 1, 5),
        DateTime(2026, 1, 6),
      );
      expect(entries.length, 1);
      expect(env.fakeScheduler.scheduled.length, 13);
    });
  });
}
