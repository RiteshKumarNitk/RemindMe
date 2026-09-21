import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notifications/notification_service.dart';
import '../data/database/app_database.dart';
import 'auth_service.dart';
import 'sync/sync_service.dart';

/// What happened when [AccountDeletionService.deleteEverything] ran, so the
/// UI can tell the user the honest outcome rather than a blanket "done."
class AccountDeletionResult {
  const AccountDeletionResult({
    required this.localDataWiped,
    required this.householdPresenceRemoved,
    required this.firebaseAccountDeleted,
    this.requiresRecentLogin = false,
    this.cloudError,
  });

  /// Always true unless the local wipe itself threw (should be extremely
  /// rare — a locked/corrupt DB file).
  final bool localDataWiped;

  /// False when the user is a household *owner* — Firestore rules refuse to
  /// let an owner delete their own member record (it would orphan the
  /// household), so only the FCM token was cleared and the record remains.
  final bool householdPresenceRemoved;

  final bool firebaseAccountDeleted;

  /// True when Firebase refused the account deletion because the sign-in is
  /// no longer "recent" — the UI should prompt the user to sign in again
  /// and retry, not just report failure.
  final bool requiresRecentLogin;

  /// Any other cloud-side error (network, permissions, …). Local data is
  /// still wiped regardless — see [localDataWiped].
  final String? cloudError;

  bool get fullyCleaned =>
      localDataWiped &&
      householdPresenceRemoved &&
      firebaseAccountDeleted &&
      cloudError == null;
}

/// Account/data deletion (Play Store account-deletion requirement). Local
/// data is always wiped on request — it needs no account, per the app's
/// offline-first design. Cloud cleanup (household presence + the Firebase
/// Auth account itself) is attempted best-effort when signed in; a failure
/// there is reported back, never allowed to block or partially-apply the
/// local wipe.
class AccountDeletionService {
  AccountDeletionService({
    required this.db,
    required this.prefs,
    required this.auth,
    required this.sync,
    required this.notifications,
  });

  final AppDatabase db;
  final SharedPreferences prefs;
  final AuthService auth;
  final SyncService sync;
  final NotificationService notifications;

  Future<AccountDeletionResult> deleteEverything() async {
    var householdPresenceRemoved = true;
    var firebaseAccountDeleted = true;
    var requiresRecentLogin = false;
    String? cloudError;

    if (auth.isSignedIn) {
      try {
        householdPresenceRemoved = await sync.backend.deleteMyHouseholdPresence();
      } catch (e) {
        developer.log('deleteMyHouseholdPresence failed: $e', name: 'AccountDeletion', error: e);
        householdPresenceRemoved = false;
        cloudError = e.toString();
      }

      try {
        await auth.deleteAccount();
      } on FirebaseAuthException catch (e) {
        firebaseAccountDeleted = false;
        if (e.code == 'requires-recent-login') {
          requiresRecentLogin = true;
        } else {
          cloudError ??= e.message ?? e.code;
        }
        developer.log('deleteAccount failed: ${e.code}', name: 'AccountDeletion', error: e);
      } catch (e) {
        firebaseAccountDeleted = false;
        cloudError ??= e.toString();
        developer.log('deleteAccount failed: $e', name: 'AccountDeletion', error: e);
      }
    }

    // Local data is wiped regardless of how the cloud steps above went —
    // it's the user's own device data and needs no account. Cancel pending
    // OS alarms first so nothing fires for medicines about to disappear.
    var localDataWiped = true;
    try {
      await notifications.cancelAllPending();
      await db.wipeAllData();
      await prefs.clear();
    } catch (e) {
      localDataWiped = false;
      developer.log('local wipe failed: $e', name: 'AccountDeletion', error: e);
    }

    return AccountDeletionResult(
      localDataWiped: localDataWiped,
      householdPresenceRemoved: householdPresenceRemoved,
      firebaseAccountDeleted: firebaseAccountDeleted,
      requiresRecentLogin: requiresRecentLogin,
      cloudError: cloudError,
    );
  }
}
