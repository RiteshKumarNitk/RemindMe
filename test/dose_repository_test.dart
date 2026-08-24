import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/data/models/dose_status.dart';
import 'package:medireminder/data/models/medicine_schedule.dart';

import 'test_helpers.dart';

void main() {
  final now = DateTime(2026, 1, 5, 9, 0);

  group('MedicineRepository', () {
    test('insert + read round-trips schedules', () async {
      final env = await TestEnv.create();
      final id = await env.medicineRepository.insert(
        makeMedicine(
          name: 'Vitamin D',
          dosage: '1',
          dosageUnit: 'drop',
          schedules: const [
            MedicineSchedule(medicineId: 0, hour: 7, minute: 0),
            MedicineSchedule(medicineId: 0, hour: 13, minute: 0),
          ],
        ),
      );

      final all = await env.medicineRepository.getAll();
      expect(all.length, 1);
      expect(all.first.id, id);
      expect(all.first.name, 'Vitamin D');
      expect(all.first.doseLabel, '1 drop');
      expect(all.first.schedules.length, 2);
      expect(all.first.schedules.first.hour, 7);
    });

    test('delete removes the medicine', () async {
      final env = await TestEnv.create();
      final id = await env.medicineRepository.insert(makeMedicine());
      await env.medicineRepository.delete(id);
      expect(await env.medicineRepository.getAll(), isEmpty);
    });
  });

  group('DoseRepository', () {
    test('ensureDose dedupes by (medicine, time)', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      final when = DateTime(2026, 1, 6, 8, 0);

      final first = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: when,
      );
      final second = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: when,
      );
      expect(first!.id, second!.id);
    });

    test('ensureDose does not touch a dose with a final outcome', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      final when = DateTime(2026, 1, 6, 8, 0);

      final dose = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: when,
      );
      await env.doseRepository.markTaken(dose!.id!, DateTime(2026, 1, 6, 8, 5));

      final again = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: when,
      );
      expect(again, isNull);
    });

    test('taken / skipped / missed statuses persist', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      final taken = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 1, 6, 8, 0),
      );
      final skipped = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 1, 6, 9, 0),
      );
      final missed = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 1, 6, 10, 0),
      );

      await env.doseRepository.markTaken(
        taken!.id!,
        DateTime(2026, 1, 6, 8, 5),
      );
      await env.doseRepository.markSkipped(
        skipped!.id!,
        DateTime(2026, 1, 6, 9, 2),
      );
      await env.doseRepository.markMissed(missed!.id!);

      final stats = await env.doseRepository.statsBetween(
        DateTime(2026, 1, 6),
        DateTime(2026, 1, 7),
        grace: const Duration(minutes: 30),
        now: DateTime(2026, 1, 6, 12, 0),
      );
      expect(stats.taken, 1);
      expect(stats.skipped, 1);
      expect(stats.missed, 1);
      expect(stats.adherencePercent, 33);
    });

    test('sweepMissed marks overdue pending doses as missed', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: now.subtract(const Duration(hours: 2)),
      );
      await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: now.subtract(const Duration(minutes: 10)),
      );

      final count = await env.doseRepository.sweepMissed(
        const Duration(minutes: 30),
        now,
      );
      expect(count, 1);

      final entries = await env.doseRepository.getEntriesBetween(
        now.subtract(const Duration(hours: 3)),
        now,
      );
      expect(entries[0].dose.status, DoseStatus.missed);
      expect(entries[1].dose.status, DoseStatus.pending);
    });

    test(
      'effective status treats snoozed-then-ignored doses as missed',
      () async {
        final env = await TestEnv.create();
        final medId = await env.medicineRepository.insert(makeMedicine());
        final dose = await env.doseRepository.ensureDose(
          medicineId: medId,
          scheduledAt: now.subtract(const Duration(hours: 1)),
        );
        await env.doseRepository.setSnoozedUntil(
          dose!.id!,
          now.subtract(const Duration(minutes: 40)),
        );

        final entries = await env.doseRepository.getEntriesBetween(
          now.subtract(const Duration(hours: 2)),
          now,
        );
        expect(
          entries.first.effectiveStatus(const Duration(minutes: 30), now),
          DoseStatus.missed,
        );
      },
    );
  });
}
