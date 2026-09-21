import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/services/account_deletion_service.dart';
import 'package:medireminder/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

void main() {
  group('AppDatabase.wipeAllData', () {
    test('clears medicines, doses, and every sync table', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await env.syncRepository.enqueueMedicine(medId, DateTime.now());
      await env.syncRepository.addMedicineTombstone(medId);
      await env.syncRepository.addDoseTombstone(medId, DateTime.now());

      expect((await env.medicineRepository.getAll()), isNotEmpty);
      expect((await env.syncRepository.countPending()), greaterThan(0));

      await env.db.wipeAllData();

      expect(await env.medicineRepository.getAll(), isEmpty);
      expect(await env.syncRepository.countPending(), 0);
      expect(await env.syncRepository.pendingDoseTombstones(), isEmpty);
    });
  });

  group('AccountDeletionService (signed-out path)', () {
    test('wipes local data and reports success with nothing to clean up in the cloud', () async {
      final env = await TestEnv.create();
      final medId = await env.medicineRepository.insert(makeMedicine());
      await env.doseRepository.ensureDose(
        medicineId: medId,
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
      );
      await env.settings.setUserName('Test User');

      // Not signed in in this harness (no live Firebase project) — exercises
      // the "nothing to do in the cloud" branch, which is also the path
      // every offline-only user (the app's default) actually takes.
      final auth = AuthService();
      final deletion = AccountDeletionService(
        db: env.db,
        prefs: await SharedPreferences.getInstance(),
        auth: auth,
        sync: env.sync,
        notifications: env.notifications,
      );

      final result = await deletion.deleteEverything();

      expect(result.localDataWiped, isTrue);
      expect(result.householdPresenceRemoved, isTrue);
      expect(result.firebaseAccountDeleted, isTrue);
      expect(result.requiresRecentLogin, isFalse);
      expect(result.fullyCleaned, isTrue);
      expect(await env.medicineRepository.getAll(), isEmpty);
    });
  });

  group('FakeBackend.deleteMyHouseholdPresence (mirrors FirebaseBackend rules)', () {
    test('a plain member is fully removed', () async {
      final backend = FakeBackend();
      await backend.createHousehold();
      backend.householdRole = 'member';

      final removed = await backend.deleteMyHouseholdPresence();

      expect(removed, isTrue);
      expect(backend.householdPresenceDeleted, isTrue);
      expect(await backend.currentHousehold(), isNull);
    });

    test('an owner cannot be fully removed — only the FCM token is cleared', () async {
      final backend = FakeBackend();
      await backend.createHousehold();
      backend.householdRole = 'owner';

      final removed = await backend.deleteMyHouseholdPresence();

      expect(removed, isFalse);
      expect(backend.householdFcmCleared, isTrue);
      expect(backend.householdPresenceDeleted, isFalse);
    });

    test('no household joined is a safe no-op success', () async {
      final backend = FakeBackend();
      final removed = await backend.deleteMyHouseholdPresence();
      expect(removed, isTrue);
    });
  });
}
