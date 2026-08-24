import 'dart:async';
import 'dart:io';

import 'package:intl/date_symbol_data_local.dart';
import 'package:medireminder/core/notifications/notification_service.dart';
import 'package:medireminder/data/database/app_database.dart';
import 'package:medireminder/data/repositories/sync_repository.dart';
import 'package:medireminder/data/models/food_instruction.dart';
import 'package:medireminder/data/models/medicine.dart';
import 'package:medireminder/data/models/medicine_frequency.dart';
import 'package:medireminder/data/models/medicine_schedule.dart';
import 'package:medireminder/data/repositories/dose_repository.dart';
import 'package:medireminder/data/repositories/medicine_repository.dart';
import 'package:medireminder/data/repositories/settings_repository.dart';
import 'package:medireminder/services/dose_action_handler.dart';
import 'package:medireminder/services/dose_scheduler.dart';
import 'package:medireminder/services/settings_controller.dart';
import 'package:medireminder/services/sync/remote_backend.dart';
import 'package:medireminder/services/sync/sync_service.dart';
import 'package:medireminder/services/voice_service.dart';
import 'package:medireminder/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// In-memory scheduler recording what would be scheduled/cancelled.
class FakeScheduler implements ReminderScheduler {
  final Map<int, DateTime> scheduled = {};
  final List<String> log = <String>[];

  @override
  Future<bool> scheduleDoseReminder({
    required int doseId,
    required String title,
    required String body,
    required DateTime when,
    required bool exact,
    required String takenLabel,
    required String snoozeLabel,
    required String skipLabel,
  }) async {
    scheduled[doseId] = when;
    log.add('schedule:$doseId@${when.toIso8601String()}');
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    log.add('cancel:$id');
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
}

/// Everything needed for a test: real repositories on an in-memory SQLite
/// database plus a [FakeScheduler] in place of the OS notification layer.
class TestEnv {
  late AppDatabase db;
  late MedicineRepository medicineRepository;
  late DoseRepository doseRepository;
  late FakeScheduler fakeScheduler;
  late SettingsController settings;
  late NotificationService notifications;
  late VoiceService voice;
  late DoseScheduler doseScheduler;
  late DoseActionHandler actionHandler;
  late SyncRepository syncRepository;
  late SyncService sync;
  late AppState appState;

  static int _dbCounter = 0;

  static Future<TestEnv> create({RemoteBackend? backend}) async {
    SharedPreferences.setMockInitialValues(const {});
    await initializeDateFormatting('en');
    await initializeDateFormatting('hi');
    sqfliteFfiInit();
    final env = TestEnv();
    // A unique temp file per environment guarantees tests are isolated
    // (the ffi factory can share in-memory databases within an isolate).
    final dir = Directory.systemTemp.createTempSync('medireminder_test');
    env.db = AppDatabase(
      factory: databaseFactoryFfi,
      path: '${dir.path}/test_${_dbCounter++}.db',
    );
    env.syncRepository = SyncRepository(env.db);
    env.medicineRepository = MedicineRepository(
      env.db,
      sync: env.syncRepository,
    );
    env.doseRepository = DoseRepository(env.db, sync: env.syncRepository);
    env.fakeScheduler = FakeScheduler();
    env.settings = SettingsController(
      SettingsRepository(await SharedPreferences.getInstance()),
    );
    await env.settings.load();
    env.notifications = NotificationService();
    env.voice = VoiceService();
    env.doseScheduler = DoseScheduler(
      medicineRepository: env.medicineRepository,
      doseRepository: env.doseRepository,
      scheduler: env.fakeScheduler,
    );
    env.sync = SyncService(
      backend: backend ?? FakeBackend(),
      medicineRepository: env.medicineRepository,
      doseRepository: env.doseRepository,
      syncRepository: env.syncRepository,
      settings: env.settings,
      notifications: env.notifications,
      prefs: await SharedPreferences.getInstance(),
      onDataChanged: () async {},
    );
    env.actionHandler = DoseActionHandler(
      doseRepository: env.doseRepository,
      medicineRepository: env.medicineRepository,
      scheduler: env.fakeScheduler,
      settings: env.settings,
      voice: env.voice,
    );
    env.appState = AppState(
      medicineRepository: env.medicineRepository,
      doseRepository: env.doseRepository,
      settings: env.settings,
      notifications: env.notifications,
      doseScheduler: env.doseScheduler,
      actionHandler: env.actionHandler,
      voice: env.voice,
      sync: env.sync,
    );
    return env;
  }
}

/// In-memory backend used by tests.
class FakeBackend implements RemoteBackend {
  final Map<int, RemoteMedicine> medicines = {};
  final Map<String, RemoteDose> doses = {};
  final StreamController<List<RemoteDose>> _watch =
      StreamController.broadcast();
  String? household;
  bool configured = true;

  /// When true, pushes throw — simulates a network outage so tests can
  /// exercise the retry/outbox machinery.
  bool failPushes = false;

  @override
  Future<void> initialize() async {
    if (!configured) throw StateError('Firebase is not configured');
  }

  @override
  Future<void> signIn() async {}

  @override
  Future<String> createHousehold() async {
    household = 'ABC123';
    return household!;
  }

  @override
  Future<String> joinHousehold(String code) async {
    if (code.toUpperCase() != 'ABC123') {
      throw StateError('Code not found');
    }
    household = code.toUpperCase();
    return household!;
  }

  @override
  Future<String?> currentHousehold() async => household;

  @override
  Future<void> attachPushToken() async {}

  @override
  Future<void> pushMedicines(List<RemoteMedicine> items) async {
    if (failPushes) throw StateError('network down');
    for (final item in items) {
      medicines[item.medicine.id ?? 0] = item;
    }
  }

  @override
  Future<void> pushDoses(List<RemoteDose> items) async {
    if (failPushes) throw StateError('network down');
    for (final item in items) {
      final d = item.dose;
      doses['${d.medicineId}_${d.scheduledAt.millisecondsSinceEpoch}'] = item;
    }
  }

  @override
  Future<List<RemoteMedicine>> pullMedicines(DateTime since) async {
    return medicines.values.where((m) => m.updatedAt.isAfter(since)).toList();
  }

  @override
  Future<List<RemoteDose>> pullDoses(DateTime since) async {
    return doses.values.where((d) => d.updatedAt.isAfter(since)).toList();
  }

  @override
  Stream<List<RemoteDose>> watchDoses() => _watch.stream;

  void emitDoses(List<RemoteDose> items) => _watch.add(items);

  @override
  Future<void> dispose() async {}
}

Medicine makeMedicine({
  int? id,
  String name = 'BP Tablet',
  String dosage = '1',
  String dosageUnit = 'tablet',
  MedicineFrequency frequency = MedicineFrequency.daily,
  List<int> selectedDays = const [],
  DateTime? onceDate,
  bool active = true,
  List<MedicineSchedule> schedules = const [
    MedicineSchedule(medicineId: 0, hour: 8, minute: 0),
  ],
  FoodInstruction foodInstruction = FoodInstruction.none,
}) {
  final now = DateTime(2026, 1, 1, 8, 0);
  return Medicine(
    id: id,
    name: name,
    dosage: dosage,
    dosageUnit: dosageUnit,
    frequency: frequency,
    selectedDays: selectedDays,
    onceDate: onceDate,
    active: active,
    createdAt: now,
    updatedAt: now,
    foodInstruction: foodInstruction,
    schedules: schedules,
  );
}
