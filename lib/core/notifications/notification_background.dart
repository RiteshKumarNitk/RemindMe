import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/dose_repository.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../../services/dose_action_handler.dart';
import '../../services/settings_controller.dart';
import '../../services/voice_service.dart';
import 'notification_service.dart';

/// Entry point for the TAKEN / SNOOZE / SKIP action buttons when they are
/// pressed while the app is in the background or fully terminated.
///
/// This runs in its own isolate with no access to the running app's state, so
/// it rebuilds just the services it needs (database + notification plugin) and
/// applies the action directly. `speak` is disabled — there is no UI/audio
/// session here.
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId == null || actionId.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();

  try {
    await NotificationService.initTimeZone();

    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsController(SettingsRepository(prefs));
    await settings.load();

    final db = AppDatabase();
    final syncRepository = SyncRepository(db);
    final medicineRepository = MedicineRepository(db, sync: syncRepository);
    final doseRepository = DoseRepository(db, sync: syncRepository);

    final notifications = NotificationService();
    await notifications.initMinimal(soundEnabled: settings.soundEnabled);

    final handler = DoseActionHandler(
      doseRepository: doseRepository,
      medicineRepository: medicineRepository,
      scheduler: notifications,
      settings: settings,
      voice: VoiceService(),
    );

    await handler.handle(
      actionId: actionId,
      payload: response.payload,
      speak: false,
    );
    developer.log('Background action "$actionId" applied', name: 'Notif');
  } catch (e, st) {
    developer.log('notificationBackgroundHandler FAILED: $e\n$st',
        name: 'Notif', error: e, stackTrace: st);
  }
}
