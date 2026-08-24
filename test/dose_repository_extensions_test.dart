import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/data/models/dose_status.dart';
import 'package:medireminder/data/models/medicine_schedule.dart';

import 'test_helpers.dart';

void main() {
  group('DoseRepository extensions', () {
    test('restorePreviousStatus reverts a dose to pending', () async {
      final env = await TestEnv.create();
      await env.appState.init();

      // Create a medicine and get its dose.
      final now = DateTime.now();
      final future = now.add(const Duration(hours: 2));
      await env.appState.saveMedicine(
        makeMedicine(
          schedules: [
            MedicineSchedule(
              medicineId: 0,
              hour: future.hour,
              minute: future.minute,
            ),
          ],
        ),
      );
      final doses = await env.doseRepository.getPendingBetween(
        now.subtract(const Duration(hours: 1)),
        now.add(const Duration(hours: 3)),
      );
      expect(doses, isNotEmpty);
      final dose = doses.first;

      // Mark it as taken.
      await env.doseRepository.markTaken(dose.id!, now);
      final taken = await env.doseRepository.getDose(dose.id!);
      expect(taken!.status, DoseStatus.taken);

      // Restore it.
      await env.doseRepository.restorePreviousStatus(
        dose.id!,
        status: DoseStatus.pending,
      );
      final restored = await env.doseRepository.getDose(dose.id!);
      expect(restored!.status, DoseStatus.pending);
    });

    test('getPendingBetween returns doses in the window', () async {
      final env = await TestEnv.create();
      await env.appState.init();

      await env.appState.saveMedicine(
        makeMedicine(
          schedules: const [
            MedicineSchedule(medicineId: 0, hour: 8, minute: 0),
          ],
        ),
      );

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final doses = await env.doseRepository.getPendingBetween(start, end);
      expect(doses, isNotEmpty);
      for (final d in doses) {
        expect(d.status, DoseStatus.pending);
      }
    });

    test('deletePendingFrom creates dose tombstones', () async {
      final env = await TestEnv.create();
      await env.appState.init();

      await env.appState.saveMedicine(
        makeMedicine(
          name: 'Test Med',
          schedules: const [
            MedicineSchedule(medicineId: 0, hour: 8, minute: 0),
          ],
        ),
      );

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = start.add(const Duration(days: 1));
      final dosesBefore = await env.doseRepository.getPendingBetween(
        start,
        end,
      );
      expect(dosesBefore, isNotEmpty);

      // Delete pending doses — should create tombstones.
      await env.doseRepository.deletePendingFrom(
        dosesBefore.first.medicineId,
        start,
      );

      final tombstones = await env.syncRepository.pendingDoseTombstones();
      expect(tombstones, isNotEmpty);
    });
  });
}
