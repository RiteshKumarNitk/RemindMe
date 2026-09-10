import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/data/models/dose_status.dart';
import 'package:medireminder/data/models/medicine_dose.dart';
import 'package:medireminder/data/models/medicine_schedule.dart';
import 'package:medireminder/data/repositories/dose_repository.dart';
import 'package:medireminder/services/sync/remote_backend.dart';
import 'package:medireminder/state/app_state.dart';

import 'test_helpers.dart';

/// Forces [restorePreviousStatus] (the first DB write of an undo) to throw so
/// the undo-state retention path can be exercised.
class _ThrowingRestoreDoseRepo extends DoseRepository {
  _ThrowingRestoreDoseRepo(super.db, {super.sync});

  bool throwOnRestore = true;

  @override
  Future<void> restorePreviousStatus(
    int id, {
    required DoseStatus status,
    DateTime? takenAt,
    DateTime? skippedAt,
  }) async {
    if (throwOnRestore) throw StateError('simulated undo failure');
    return super.restorePreviousStatus(
      id,
      status: status,
      takenAt: takenAt,
      skippedAt: skippedAt,
    );
  }
}

Future<void> settle(dynamic sync) async {
  while (sync.syncing == true) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('#16 deletePendingFrom is atomic (tombstone + delete)', () {
    test('pending doses vanish AND matching tombstones are recorded', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 6, 1, 8),
      );
      await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 6, 2, 8),
      );

      await env.doseRepository.deletePendingFrom(medId, DateTime(2026, 1, 1));

      final remaining = await env.doseRepository.getPendingBetween(
        DateTime(2026, 1, 1),
        DateTime(2027, 1, 1),
      );
      expect(remaining, isEmpty);

      final tombs = await env.syncRepository.pendingDoseTombstones();
      expect(tombs.length, 2,
          reason: 'a tombstone per deleted dose, committed in the same txn');
    });
  });

  group('#3 / #5 FK ON DELETE CASCADE', () {
    test('a raw delete of a medicine removes its child doses', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 6, 1, 8),
      );

      final db = await env.db.database;
      // Bypass the repository's belt-and-suspenders cleanup to prove the
      // database itself enforces the cascade.
      await db.delete('medicines', where: 'id = ?', whereArgs: [medId]);

      final orphans = await db.query('medicine_doses');
      expect(orphans, isEmpty,
          reason: 'ON DELETE CASCADE should drop child doses');
    });
  });

  group('#17 undo state is retained when restore/refresh fails', () {
    test('canUndo stays true and lastUndoFailed is set', () async {
      final env = await TestEnv.create();
      final throwingRepo = _ThrowingRestoreDoseRepo(
        env.db,
        sync: env.syncRepository,
      );
      final appState = AppState(
        medicineRepository: env.medicineRepository,
        doseRepository: throwingRepo,
        settings: env.settings,
        notifications: env.notifications,
        doseScheduler: env.doseScheduler,
        actionHandler: env.actionHandler,
        voice: env.voice,
        sync: env.sync,
      );

      final medId = await env.medicineRepository.insert(makeMedicine(
        schedules: const [MedicineSchedule(medicineId: 0, hour: 8, minute: 0)],
      ));
      final dose = await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime(2026, 1, 6, 8),
      );
      final entry = await env.doseRepository.getDoseEntry(dose!.id!);

      await appState.markTaken(entry!);
      expect(appState.canUndo, isTrue);

      await appState.undoLastAction();

      expect(appState.canUndo, isTrue,
          reason: 'a failed undo must remain retryable');
      expect(appState.lastUndoFailed, isTrue);

      // Once the write can succeed, undo goes through and the snapshot clears.
      throwingRepo.throwOnRestore = false;
      await appState.undoLastAction();
      expect(appState.canUndo, isFalse);
      expect(appState.lastUndoFailed, isFalse);
    });
  });

  group('#9 sync checkpoint is clock-jump safe', () {
    test('checkpoint is not rewound behind a future value on an empty pull',
        () async {
      final env = await TestEnv.create();
      await env.sync.enableSync(role: 'primary');
      await settle(env.sync);

      // A checkpoint written earlier by a client whose clock ran fast.
      final future = DateTime.now().add(const Duration(hours: 2));
      await env.settings.setLastSyncAt(future);

      await env.sync.syncNow();
      await settle(env.sync);

      expect(env.sync.lastSyncAt!.isBefore(future), isFalse,
          reason: 'nothing new was pulled, so the checkpoint must hold');
    });

    test('checkpoint never advances past the wall clock', () async {
      final shared = FakeBackend();
      final a = await TestEnv.create(backend: shared);
      await a.sync.enableSync(role: 'primary');
      await settle(a.sync);

      // A peer with a fast clock wrote a dose stamped 2h in the future.
      final futureStamp = DateTime.now().add(const Duration(hours: 2));
      shared.doses['999_${futureStamp.millisecondsSinceEpoch}'] = RemoteDose(
        MedicineDose(
          medicineId: 999,
          scheduledAt: DateTime(2026, 1, 1, 8),
          updatedAt: futureStamp,
        ),
        'Ghost',
        false,
        futureStamp,
      );

      await a.sync.syncNow();
      await settle(a.sync);

      final ceiling = DateTime.now().add(const Duration(minutes: 1));
      expect(a.sync.lastSyncAt!.isAfter(ceiling), isFalse,
          reason: 'checkpoint must be clamped to ~now, not the future stamp');
    });
  });
}
