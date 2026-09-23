import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/platform_api_config.dart';
import 'core/notifications/notification_service.dart';
import 'data/api/api_client.dart';
import 'data/api/secure_token_store.dart';
import 'data/database/app_database.dart';
import 'data/repositories/appointment_repository.dart';
import 'data/repositories/dose_repository.dart';
import 'data/repositories/healthcare_repository.dart';
import 'data/repositories/medicine_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'services/account_deletion_service.dart';
import 'services/platform_auth_service.dart';
import 'services/auth_service.dart';
import 'services/dose_action_handler.dart';
import 'services/dose_scheduler.dart';
import 'services/settings_controller.dart';
import 'services/sync/firebase_backend.dart';
import 'services/sync/sync_service.dart';
import 'services/voice_service.dart';
import 'state/app_state.dart';

/// Flipped to true once `FirebaseCrashlytics` is safely initialized (i.e.
/// Firebase itself came up). Every error handler below checks this before
/// touching Crashlytics, so a device with Firebase unreachable/unconfigured
/// degrades to local-only `developer.log` — exactly like every other
/// Firebase-touching path in this app (see AuthService/FirebaseBackend).
bool _crashlyticsReady = false;

void main() {
  // Guard the whole boot so a failure in any single step can't leave the user
  // staring at a blank window — `runApp` still runs from `_bootstrap`.
  runZonedGuarded(_bootstrap, (e, st) {
    developer.log('Uncaught zone error', name: 'FlutterError', error: e, stackTrace: st);
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
    }
  });
}

/// Makes Flutter-framework errors (widget build/layout/paint exceptions) and
/// errors escaping Flutter's own error zone visible in `developer.log`
/// (always) and, once Firebase/Crashlytics has initialized, reported to
/// Crashlytics too — this does not change how Flutter recovers from the
/// error (the default red/grey error widget behavior is preserved by still
/// calling `presentError`).
void _installErrorHandlers() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    developer.log(
      'FlutterError',
      name: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.recordFlutterError(details);
    }
    previousOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log('Platform dispatcher error', name: 'FlutterError', error: error, stackTrace: stack);
    if (_crashlyticsReady) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }
    return false; // let the zone guard / OS also see it
  };
}

/// Enables Crashlytics collection (off in debug builds — local `developer.log`
/// already covers dev-time visibility, and debug noise isn't useful in the
/// dashboard) and flips [_crashlyticsReady] so the handlers above start
/// forwarding. Wrapped in the same timeout-guarded, swallow-on-failure
/// pattern as every other boot step — Crashlytics being unavailable must
/// never block the reminder app from starting.
Future<void> _initCrashlytics() async {
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode);
  _crashlyticsReady = true;
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();
  debugPrint('[Boot] Starting bootstrap...');

  await _guard('timezone', () => NotificationService.initTimeZone());
  await _guard('firebase', () => Firebase.initializeApp());
  debugPrint('[Boot] Firebase initialized');
  await _guard('crashlytics', _initCrashlytics);

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(SettingsRepository(prefs));
  await settings.load();
  Intl.defaultLocale = settings.settings.locale;
  await _guard('intl-en', () => initializeDateFormatting('en'));
  await _guard('intl-hi', () => initializeDateFormatting('hi'));

  final db = AppDatabase();
  final syncRepository = SyncRepository(db);
  final medicineRepository = MedicineRepository(db, sync: syncRepository);
  final doseRepository = DoseRepository(db, sync: syncRepository);
  final notifications = NotificationService();
  final voice = VoiceService();

  final doseScheduler = DoseScheduler(
    medicineRepository: medicineRepository,
    doseRepository: doseRepository,
    scheduler: notifications,
  );
  final actionHandler = DoseActionHandler(
    doseRepository: doseRepository,
    medicineRepository: medicineRepository,
    scheduler: notifications,
    settings: settings,
    voice: voice,
  );
  final auth = AuthService();
  final sync = SyncService(
    backend: FirebaseBackend(),
    medicineRepository: medicineRepository,
    doseRepository: doseRepository,
    syncRepository: syncRepository,
    settings: settings,
    notifications: notifications,
    prefs: prefs,
    connectivity: Connectivity(),
  );
  final appState = AppState(
    medicineRepository: medicineRepository,
    doseRepository: doseRepository,
    settings: settings,
    notifications: notifications,
    doseScheduler: doseScheduler,
    actionHandler: actionHandler,
    voice: voice,
    sync: sync,
  );
  sync.onDataChanged = () => appState.refresh();
  final accountDeletion = AccountDeletionService(
    db: db,
    prefs: prefs,
    auth: auth,
    sync: sync,
    notifications: notifications,
  );

  // Healthcare features (clinic discovery + appointment booking) read and
  // write the clinic platform through its REST API — a separate account and
  // a separate server from the medicine-reminder data above.
  await _guard('platformApiConfig', () => PlatformApiConfig.load());
  final apiClient = ApiClient(tokenStore: SecureTokenStore());
  final healthcareRepository = HealthcareRepository(client: apiClient);
  final appointmentRepository = AppointmentRepository(
    client: apiClient,
    healthcare: healthcareRepository,
  );
  final platformAuth = PlatformAuthService(client: apiClient);

  await _guard(
    'notifications.init',
    () => notifications.init(
      soundEnabled: settings.soundEnabled,
      onResponse: (NotificationResponse response) {
        developer.log(
          'DOSE_ALARM_FIRE source=foreground actionId=${response.actionId} '
          'payload=${response.payload}',
          name: 'DoseAudit',
        );
        appState.handleNotificationTap(
          actionId: response.actionId,
          payload: response.payload,
        );
      },
    ),
  );
  debugPrint('[Boot] Notifications initialized: ${notifications.initialized}');

  // Load local data + reconcile the OS notifications. With windowDays small and
  // the exact-mode short-circuit this finishes in ~1–2 s; the _guard timeout
  // still protects the splash if a platform call ever stalls.
  await _guard('appState.init', () => appState.init(deferScheduleSync: true));
  debugPrint('[Boot] AppState loaded (deferred schedule sync)');

  runApp(MediReminderApp(
    appState: appState,
    settings: settings,
    sync: sync,
    auth: auth,
    accountDeletion: accountDeletion,
    platformAuth: platformAuth,
    healthcare: healthcareRepository,
    appointments: appointmentRepository,
  ));

  // Everything below happens AFTER the UI is on screen. Nothing here may block
  // launch — permission prompts open system Activities, TTS/cloud init can be
  // slow, and none of it is needed for the first frame.
  unawaited(_postLaunch(notifications, appState, sync, voice, platformAuth));
}

Future<void> _postLaunch(
  NotificationService notifications,
  AppState appState,
  SyncService sync,
  VoiceService voice,
  PlatformAuthService platformAuth,
) async {
  await _guard('voice.init', () => voice.init());
  await _guard('sync.init', () => sync.init());
  // Restores a stored clinic-platform session in the background; the
  // medicine reminder flow above never waits on the network.
  await _guard('platformSession.restore', platformAuth.restore);

  await _guard('notif.permission', () async {
    final enabled = await notifications.areNotificationsEnabled();
    debugPrint('[Boot] Notifications enabled: $enabled');
    if (!enabled) {
      final granted = await notifications.requestPermission();
      debugPrint('[Boot] Notification permission request result: $granted');
    }
  });
  await _guard(
    'exact-alarm.permission',
    () => notifications.requestExactAlarmPermission(),
  );
  final canExact = await notifications.canScheduleExact();
  debugPrint('[Boot] Can schedule exact alarms: $canExact');
  await _guard(
    'fullscreen.permission',
    () => notifications.requestFullScreenIntentPermission(),
  );
  await _guard('refreshPerms', () => appState.refreshPermissionStatus());
  debugPrint('[Boot] All permissions refreshed');

  // Run the full schedule sync in the background — reconcile all OS
  // notifications with the database. This is slow on first run (~2s)
  // but fast on subsequent runs (~200ms).
  unawaited(_backgroundScheduleSync(appState, notifications));

  await _guard('cold-start-notif', () async {
    final launch = await notifications.getLaunchDetails();
    final r = launch?.notificationResponse;
    if (r != null && r.payload != null && r.payload!.isNotEmpty) {
      developer.log(
        'DOSE_ALARM_FIRE source=cold-start actionId=${r.actionId} payload=${r.payload}',
        name: 'DoseAudit',
      );
      await appState.handleNotificationTap(
        actionId: r.actionId,
        payload: r.payload,
      );
    }
  });
}

/// Runs the schedule sync in the background after the UI is visible.
/// This is the most important step for notification reliability — it
/// reconciles every pending dose with the OS alarm manager.
Future<void> _backgroundScheduleSync(
  AppState appState,
  NotificationService notifications,
) async {
  debugPrint('[Boot] Starting background schedule sync...');
  await _guard('schedule-sync', () async {
    await appState.refresh();
    final pending = await notifications.pendingIds();
    debugPrint('[Boot] Schedule sync complete. ${pending.length} notifications pending in OS.');
  });
}

Future<void> _guard(String label, Future<void> Function() body) async {
  try {
    await body().timeout(const Duration(seconds: 20));
  } catch (e, st) {
    debugPrint('boot step "$label" failed (continuing): $e\n$st');
  }
}
