import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/notifications/notification_service.dart';
import 'data/database/app_database.dart';
import 'data/repositories/dose_repository.dart';
import 'data/repositories/medicine_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'services/auth_service.dart';
import 'services/dose_action_handler.dart';
import 'services/dose_scheduler.dart';
import 'services/settings_controller.dart';
import 'services/sync/firebase_backend.dart';
import 'services/sync/sync_service.dart';
import 'services/voice_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initTimeZone();

  // Initialize Firebase BEFORE anything touches FirebaseAuth/Firestore.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Firebase not configured (missing google-services.json) — app works
    // fully offline. AuthService and SyncService handle this gracefully.
  }

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsController(SettingsRepository(prefs));
  await settings.load();
  Intl.defaultLocale = settings.settings.locale;
  // Load date-formatting data for every supported locale up front.
  await initializeDateFormatting('en');
  await initializeDateFormatting('hi');

  final db = AppDatabase();
  final syncRepository = SyncRepository(db);
  final medicineRepository = MedicineRepository(db, sync: syncRepository);
  final doseRepository = DoseRepository(db, sync: syncRepository);
  final notifications = NotificationService();
  final voice = VoiceService();
  await voice.init();

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

  await notifications.init(
    soundEnabled: settings.soundEnabled,
    onResponse: (NotificationResponse response) {
      appState.handleNotificationTap(
        actionId: response.actionId,
        payload: response.payload,
      );
    },
  );

  await sync.init();
  // Defer the (slow) notification reconcile so the splash never blocks on it.
  await appState.init(deferScheduleSync: true);

  // Auto-request notification permission on every launch.
  if (!await notifications.areNotificationsEnabled()) {
    await notifications.requestPermission();
  }
  // Also ensure exact alarms are available (Android 12+).
  await notifications.requestExactAlarmPermission();
  // Android 14+: needed for the lock-screen full-screen dose alarm.
  await notifications.requestFullScreenIntentPermission();
  // Re-check after the request so the UI can show the correct banner.
  await appState.refreshPermissionStatus();

  // Cold start from a notification tap / action button.
  final launch = await notifications.getLaunchDetails();
  final launchResponse = launch?.notificationResponse;
  if (launchResponse != null &&
      launchResponse.payload != null &&
      launchResponse.payload!.isNotEmpty) {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      appState.handleNotificationTap(
        actionId: launchResponse.actionId,
        payload: launchResponse.payload,
      );
    });
  }

  runApp(MediReminderApp(
    appState: appState,
    settings: settings,
    sync: sync,
    auth: auth,
  ));
}
