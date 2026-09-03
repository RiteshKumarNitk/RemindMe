import 'dart:async';

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

void main() {
  // Guard the whole boot so a failure in any single step can't leave the user
  // staring at a blank window — `runApp` still runs from `_bootstrap`.
  runZonedGuarded(_bootstrap, (e, st) {
    debugPrint('Uncaught zone error: $e\n$st');
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _guard('timezone', () => NotificationService.initTimeZone());
  await _guard('firebase', () => Firebase.initializeApp());

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

  await _guard(
    'notifications.init',
    () => notifications.init(
      soundEnabled: settings.soundEnabled,
      onResponse: (NotificationResponse response) {
        appState.handleNotificationTap(
          actionId: response.actionId,
          payload: response.payload,
        );
      },
    ),
  );

  // Fast: local DB read + a few platform reads. Schedule reconcile is deferred
  // to the background so it can never block first paint.
  await _guard('appState.init', () => appState.init(deferScheduleSync: true));

  runApp(MediReminderApp(
    appState: appState,
    settings: settings,
    sync: sync,
    auth: auth,
  ));

  // Everything below happens AFTER the UI is on screen. Nothing here may block
  // launch — permission prompts open system Activities, TTS/cloud init can be
  // slow, and none of it is needed for the first frame.
  unawaited(_postLaunch(notifications, appState, sync, voice));
}

Future<void> _postLaunch(
  NotificationService notifications,
  AppState appState,
  SyncService sync,
  VoiceService voice,
) async {
  await _guard('voice.init', () => voice.init());
  await _guard('sync.init', () => sync.init());

  await _guard('notif.permission', () async {
    if (!await notifications.areNotificationsEnabled()) {
      await notifications.requestPermission();
    }
  });
  await _guard(
    'exact-alarm.permission',
    () => notifications.requestExactAlarmPermission(),
  );
  await _guard(
    'fullscreen.permission',
    () => notifications.requestFullScreenIntentPermission(),
  );
  await _guard('refreshPerms', () => appState.refreshPermissionStatus());

  await _guard('cold-start-notif', () async {
    final launch = await notifications.getLaunchDetails();
    final r = launch?.notificationResponse;
    if (r != null && r.payload != null && r.payload!.isNotEmpty) {
      await appState.handleNotificationTap(
        actionId: r.actionId,
        payload: r.payload,
      );
    }
  });
}

Future<void> _guard(String label, Future<void> Function() body) async {
  try {
    await body().timeout(const Duration(seconds: 20));
  } catch (e, st) {
    debugPrint('boot step "$label" failed (continuing): $e\n$st');
  }
}
