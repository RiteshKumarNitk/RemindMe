import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/core/notifications/notification_service.dart';
import 'package:medireminder/data/models/dose_status.dart';
import 'package:medireminder/data/models/medicine_dose.dart';
import 'package:medireminder/data/repositories/sync_repository.dart';
import 'package:medireminder/services/sync/remote_backend.dart';
import 'package:medireminder/services/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

/// Records missed-dose alerts instead of showing real notifications.
class RecordingNotifications extends NotificationService {
  int missedAlerts = 0;

  @override
  Future<void> showMissedAlert({
    required String title,
    required String body,
  }) async {
    missedAlerts++;
  }
}

/// Waits until the (fire-and-forget) sync triggered by an app-state mutation
/// has finished so tests are deterministic.
Future<void> settle(SyncService sync) async {
  while (sync.syncing) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  group('SyncService', () {
    test('primary enable sync pushes local data and checkpoints', () async {
      final env = await TestEnv.create();
      await env.appState.saveMedicine(
        makeMedicine(name: 'BP Tablet', dosage: '1', dosageUnit: 'tablet'),
      );
      await settle(env.sync);

      await env.sync.enableSync(role: 'primary');

      final backend = env.sync.backend as FakeBackend;
      expect(backend.household, 'ABC123');
      expect(backend.medicines.length, 1);
      expect(backend.medicines.values.first.deleted, isFalse);
      expect(env.settings.syncEnabled, isTrue);
      expect(env.sync.lastSyncAt, isNotNull);
    });

    test(
      'watcher joins a household and receives medicines and doses',
      () async {
        final shared = FakeBackend();
        final mom = await TestEnv.create(backend: shared);
        await mom.appState.saveMedicine(makeMedicine(name: 'Calcium'));
        await settle(mom.sync);

        // Mom's phone pushes everything to the shared household.
        await mom.sync.enableSync(role: 'primary');
        expect(shared.medicines.length, 1);

        // The caregiver install joins with the code and gets the data.
        final caregiver = await TestEnv.create(backend: shared);
        await caregiver.sync.enableSync(role: 'watcher', joinCode: 'ABC123');

        final meds = await caregiver.medicineRepository.getAll();
        expect(meds.length, 1);
        expect(meds.first.name, 'Calcium');
        // Caregiver also has the dose history.
        final doses = await caregiver.doseRepository.getAllUpdatedSince(
          DateTime(2020),
        );
        expect(doses, isNotEmpty);
      },
    );

    test(
      'a remote medicine edit reaches the caregiver on the next sync',
      () async {
        final shared = FakeBackend();
        final mom = await TestEnv.create(backend: shared);
        await mom.appState.saveMedicine(makeMedicine(name: 'Vitamin D'));
        await settle(mom.sync);
        await mom.sync.enableSync(role: 'primary');

        // Mom edits the medicine (new dose amount) via the repository, then
        // syncs explicitly (avoids the fire-and-forget sync race).
        final existing = (await mom.medicineRepository.getAll()).first;
        await mom.medicineRepository.update(
          existing.copyWith(dosage: '2', updatedAt: DateTime.now()),
        );
        await mom.sync.syncNow();

        final caregiver = await TestEnv.create(backend: shared);
        await caregiver.sync.enableSync(role: 'watcher', joinCode: 'ABC123');
        final meds = await caregiver.medicineRepository.getAll();
        expect(meds.first.dosage, '2');
      },
    );

    test('a remote medicine deletion removes it on the other phone', () async {
      final shared = FakeBackend();
      final mom = await TestEnv.create(backend: shared);
      final medId = await mom.medicineRepository.insert(makeMedicine());
      await mom.sync.enableSync(role: 'primary');

      final caregiver = await TestEnv.create(backend: shared);
      await caregiver.sync.enableSync(role: 'watcher', joinCode: 'ABC123');
      expect(await caregiver.medicineRepository.getAll(), hasLength(1));

      // Mom deletes the medicine; the tombstone propagates. Wait until the
      // fire-and-forget sync has actually uploaded it.
      await mom.appState.deleteMedicine(medId);
      for (
        var i = 0;
        i < 200 && !(shared.medicines[medId]?.deleted ?? false);
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(shared.medicines[medId]?.deleted, isTrue);

      await caregiver.sync.syncNow();
      expect(await caregiver.medicineRepository.getAll(), isEmpty);
    });

    test('watcher gets exactly one alert per missed dose', () async {
      final shared = FakeBackend();
      final env = await TestEnv.create(backend: shared);
      await env.settings.setSyncSettings(
        syncEnabled: true,
        householdCode: 'ABC123',
        syncRole: 'watcher',
        lastSyncAt: null,
      );
      final recording = RecordingNotifications();
      final sync = SyncService(
        backend: shared,
        medicineRepository: env.medicineRepository,
        doseRepository: env.doseRepository,
        syncRepository: env.syncRepository,
        settings: env.settings,
        notifications: recording,
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(sync.dispose);

      // A recent missed dose arrives on the shared backend.
      shared.pushDoses([
        RemoteDose(
          MedicineDose(
            medicineId: 1,
            scheduledAt: DateTime.now().subtract(const Duration(hours: 2)),
            status: DoseStatus.missed,
          ),
          'BP Tablet',
          false,
          DateTime.now(),
        ),
      ]);

      await sync.syncNow();
      expect(recording.missedAlerts, 1);

      // A second sync does not alert again for the same dose.
      await sync.syncNow();
      expect(recording.missedAlerts, 1);
    });

    test('old missed doses are not alerted (24h cutoff)', () async {
      final shared = FakeBackend();
      final env = await TestEnv.create(backend: shared);
      await env.settings.setSyncSettings(
        syncEnabled: true,
        householdCode: 'ABC123',
        syncRole: 'watcher',
        lastSyncAt: null,
      );
      final recording = RecordingNotifications();
      final sync = SyncService(
        backend: shared,
        medicineRepository: env.medicineRepository,
        doseRepository: env.doseRepository,
        syncRepository: env.syncRepository,
        settings: env.settings,
        notifications: recording,
        prefs: await SharedPreferences.getInstance(),
      );
      addTearDown(sync.dispose);

      shared.pushDoses([
        RemoteDose(
          MedicineDose(
            medicineId: 1,
            scheduledAt: DateTime.now().subtract(const Duration(days: 3)),
            status: DoseStatus.missed,
          ),
          'BP Tablet',
          false,
          DateTime.now(),
        ),
      ]);

      await sync.syncNow();
      expect(recording.missedAlerts, 0);
    });

    test(
      'sync degrades gracefully when the backend is not configured',
      () async {
        final env = await TestEnv.create(
          backend: FakeBackend()..configured = false,
        );
        await expectLater(
          env.sync.enableSync(role: 'primary'),
          throwsStateError,
        );
        expect(env.settings.syncEnabled, isFalse);
        expect(env.sync.lastError, contains('not configured'));
      },
    );

    test('local writes are queued before sync is ever enabled', () async {
      final env = await TestEnv.create();
      await env.appState.saveMedicine(makeMedicine(name: 'Calcium'));
      await settle(env.sync);

      final pending = await env.syncRepository.pendingOutbox();
      expect(pending.any((e) => e.type == SyncRepository.medicineType), isTrue);
      expect(pending.any((e) => e.type == SyncRepository.doseType), isTrue);
    });

    test(
      'failed sync keeps the queue; success drains it and resets backoff',
      () async {
        final env = await TestEnv.create();
        final backend = env.sync.backend as FakeBackend;
        await env.appState.saveMedicine(makeMedicine(name: 'BP Tablet'));
        await settle(env.sync);
        await env.sync.enableSync(role: 'primary');
        expect(backend.medicines, hasLength(1));

        // Local change while the network is down: the change stays queued and
        // the backoff retry is armed.
        backend.failPushes = true;
        final existing = (await env.medicineRepository.getAll()).first;
        await env.medicineRepository.update(
          existing.copyWith(dosage: '2', updatedAt: DateTime.now()),
        );
        await env.sync.syncNow();
        expect(backend.medicines.values.first.medicine.dosage, '1');
        expect(env.sync.retryAttempt, 1);
        expect(env.sync.nextRetryAt, isNotNull);
        expect(env.sync.pendingCount, greaterThan(0));
        expect(await env.syncRepository.pendingOutbox(), isNotEmpty);

        // Network is back: the queue drains on the next attempt.
        backend.failPushes = false;
        await env.sync.syncNow();
        expect(backend.medicines.values.first.medicine.dosage, '2');
        expect(env.sync.pendingCount, 0);
        expect(await env.syncRepository.pendingOutbox(), isEmpty);
        expect(env.sync.retryAttempt, 0);
        expect(env.sync.nextRetryAt, isNull);
      },
    );

    test('backoff grows with consecutive failures', () async {
      final env = await TestEnv.create(
        backend: FakeBackend()..failPushes = true,
      );
      addTearDown(env.sync.dispose);
      await env.appState.saveMedicine(makeMedicine(name: 'Vitamin D'));
      await settle(env.sync);
      await env.settings.setSyncSettings(
        syncEnabled: true,
        householdCode: 'ABC123',
        syncRole: 'primary',
        lastSyncAt: null,
      );

      await env.sync.syncNow();
      expect(env.sync.retryAttempt, 1);
      expect(env.sync.nextRetryAt, isNotNull);
      expect(env.sync.lastError, isNotNull);

      await env.sync.syncNow();
      expect(env.sync.retryAttempt, 2);
      expect(env.sync.nextRetryAt, isNotNull);
      expect(env.sync.pendingCount, greaterThan(0));
    });

    test(
      'checkpoint reconcile re-queues changes lost from the outbox',
      () async {
        final env = await TestEnv.create();
        final backend = env.sync.backend as FakeBackend;
        await env.appState.saveMedicine(makeMedicine(name: 'Vitamin D'));
        await settle(env.sync);
        await env.sync.enableSync(role: 'primary');
        expect(backend.medicines, hasLength(1));

        // A local change is queued, then the queue is lost (simulates an
        // upgrade or a corrupted outbox).
        final existing = (await env.medicineRepository.getAll()).first;
        await env.medicineRepository.update(
          existing.copyWith(dosage: '2', updatedAt: DateTime.now()),
        );
        await env.syncRepository.clearOutbox();

        // App restart: init() reconciles rows changed since the checkpoint.
        await env.sync.init();
        // Allow the unawaited syncNow() inside init() to start.
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await settle(env.sync);
        expect(backend.medicines.values.first.medicine.dosage, '2');
        expect(env.sync.pendingCount, 0);
      },
    );
  });
}
