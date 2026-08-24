import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/core/constants/app_constants.dart';
import 'package:medireminder/data/models/dose_status.dart';

import 'test_helpers.dart';

void main() {
  final now = DateTime(2026, 1, 5, 8, 5);

  group('DoseActionHandler', () {
    test(
      'taken action marks the dose taken and cancels the notification',
      () async {
        final env = await TestEnv.create();
        final medId = await env.medicineRepository.insert(makeMedicine());
        final dose = await env.doseRepository.ensureDose(
          medicineId: medId,
          scheduledAt: DateTime(2026, 1, 5, 8, 0),
        );
        await env.fakeScheduler.scheduleDoseReminder(
          doseId: dose!.id!,
          title: 't',
          body: 'b',
          when: DateTime(2026, 1, 5, 8, 0),
          exact: true,
          takenLabel: 'TAKEN',
          snoozeLabel: 'SNOOZE',
          skipLabel: 'SKIP',
        );

        await env.actionHandler.handle(
          actionId: AppConstants.actionTaken,
          payload: '${AppConstants.payloadPrefix}${dose.id}',
          now: now,
          speak: false,
        );

        final updated = await env.doseRepository.getDose(dose.id!);
        expect(updated!.status, DoseStatus.taken);
        expect(updated.takenAt, now);
        expect(env.fakeScheduler.scheduled.containsKey(dose.id), isFalse);
      },
    );

    test('skip action marks the dose skipped', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      final dose = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 1, 5, 8, 0),
      );

      await env.actionHandler.handle(
        actionId: AppConstants.actionSkip,
        payload: '${AppConstants.payloadPrefix}${dose!.id}',
        now: now,
      );

      final updated = await env.doseRepository.getDose(dose.id!);
      expect(updated!.status, DoseStatus.skipped);
      expect(updated.skippedAt, now);
    });

    test('snooze action reschedules for snoozeMinutes later', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      final dose = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 1, 5, 8, 0),
      );

      await env.actionHandler.handle(
        actionId: AppConstants.actionSnooze,
        payload: '${AppConstants.payloadPrefix}${dose!.id}',
        now: now,
      );

      final updated = await env.doseRepository.getDose(dose.id!);
      expect(updated!.snoozedUntil, now.add(const Duration(minutes: 10)));
      expect(
        env.fakeScheduler.scheduled[dose.id],
        now.add(const Duration(minutes: 10)),
      );
    });

    test('ignores unknown payloads', () async {
      final env = await TestEnv.create();
      await env.actionHandler.handle(
        actionId: AppConstants.actionTaken,
        payload: 'nonsense',
      );
      // No exception, nothing happened.
      expect(env.fakeScheduler.log, isEmpty);
    });
  });
}
