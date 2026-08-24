import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_text.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_status.dart';
import '../../data/models/medicine.dart';
import '../../data/models/medicine_dose.dart';
import '../../data/repositories/dose_repository.dart';
import '../../data/repositories/medicine_repository.dart';
import '../../data/repositories/sync_repository.dart';
import '../settings_controller.dart';
import 'remote_backend.dart';

/// Keeps the local SQLite database in sync with the cloud household.
/// Offline-first: the local DB is the source of truth, and sync is
/// last-writer-wins on `updatedAt`.
///
/// Reliability model:
/// - Every local mutation is queued into a persistent outbox (`sync_outbox`)
///   at write time, so pending changes survive network outages, app restarts
///   and even clock jumps.
/// - Pushes drain the outbox; entries are removed only after the backend
///   confirms them. Failures keep the queue and retry with exponential
///   backoff (plus an immediate attempt when connectivity returns).
/// - A checkpoint reconcile re-queues anything changed since the last
///   successful sync, as a safety net for upgrades or a lost outbox.
class SyncService extends ChangeNotifier {
  SyncService({
    required this.backend,
    required this.medicineRepository,
    required this.doseRepository,
    required this.syncRepository,
    required this.settings,
    required this.notifications,
    required this.prefs,
    this.onDataChanged,
    this.connectivity,
    Random? random,
  }) : _random = random ?? Random();

  final RemoteBackend backend;
  final MedicineRepository medicineRepository;
  final DoseRepository doseRepository;
  final SyncRepository syncRepository;
  final SettingsController settings;
  final NotificationService notifications;
  final SharedPreferences prefs;

  /// Optional connectivity monitor: when provided, a sync is triggered as
  /// soon as the network comes back after being offline. Not wired in tests.
  final Connectivity? connectivity;

  final Random _random;

  /// Called after a successful sync so the UI + notifications can refresh.
  /// Mutable because [SyncService] and [AppState] are constructed in a cycle
  /// (the app state wires itself up after both exist).
  Future<void> Function()? onDataChanged;

  static const _syncInterval = Duration(minutes: 10);
  static const _retryBase = Duration(seconds: 30);
  static const _retryMax = Duration(minutes: 10);
  static const _notifiedKey = 'missed_alerts_notified';

  bool _syncing = false;
  String? _lastError;
  DateTime? _lastSyncAt;
  Timer? _timer;
  Timer? _retryTimer;
  DateTime? _nextRetryAt;
  int _retryAttempt = 0;
  int _pendingCount = 0;
  StreamSubscription<List<RemoteDose>>? _watch;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOffline = false;
  final Set<String> _notifiedMissed = {};

  bool get syncing => _syncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncAt => _lastSyncAt;
  bool get enabled => settings.settings.syncEnabled;
  String get householdCode => settings.settings.householdCode;
  String get role => settings.settings.syncRole;

  /// How many consecutive attempts have failed (reset after a success).
  int get retryAttempt => _retryAttempt;

  /// When the automatic backoff retry is scheduled to fire, if any.
  DateTime? get nextRetryAt => _nextRetryAt;

  /// Number of local changes waiting to be uploaded (outbox + tombstones).
  int get pendingCount => _pendingCount;

  /// Restores state after app start. Re-queues anything changed since the
  /// last checkpoint and starts the periodic timer when sync is enabled.
  Future<void> init() async {
    _lastSyncAt = settings.settings.lastSyncAt;
    _notifiedMissed.addAll(prefs.getStringList(_notifiedKey) ?? const []);
    if (settings.settings.syncEnabled) {
      await _reconcileOutbox();
      await _startPeriodic();
      unawaited(syncNow());
    }
    await _refreshPendingCount();
  }

  /// Turns sync on: creates or joins a household, then does a full sync.
  /// Throws when the backend is not configured or the code is invalid.
  Future<void> enableSync({required String role, String? joinCode}) async {
    try {
      await backend.initialize();
      await backend.signIn();
      String code;
      if (joinCode != null && joinCode.trim().isNotEmpty) {
        code = await backend.joinHousehold(joinCode);
      } else {
        code = await backend.createHousehold();
      }
      await backend.attachPushToken();
      await settings.setSyncSettings(
        syncEnabled: true,
        householdCode: code,
        syncRole: role,
        lastSyncAt: null, // force a full sync
      );
      _lastSyncAt = null;
      _lastError = null;
      // Queue the whole database: everything must reach the household at
      // least once (upserts keep this cheap on repeat runs).
      await _reconcileOutbox();
      await _startPeriodic();
      await syncNow();
      notifyListeners();
    } catch (e) {
      _lastError = '$e';
      notifyListeners();
      rethrow;
    }
  }

  /// Records a local medicine deletion for propagation, then syncs.
  Future<void> tombstoneMedicine(int id) async {
    await syncRepository.addMedicineTombstone(id);
    await _refreshPendingCount();
    await syncNow();
  }

  Future<void> disableSync() async {
    _timer?.cancel();
    _timer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _nextRetryAt = null;
    _retryAttempt = 0;
    await _connectivitySub?.cancel();
    _connectivitySub = null;
    await _watch?.cancel();
    _watch = null;
    await settings.setSyncSettings(
      syncEnabled: false,
      householdCode: '',
      syncRole: 'primary',
      lastSyncAt: _lastSyncAt,
    );
    _lastSyncAt = null;
    _pendingCount = 0;
    notifyListeners();
  }

  /// Pulls remote changes, applies them locally, drains the outbox, then
  /// checkpoints. Safe to call often — it is a no-op while already syncing.
  /// Failures keep the queue intact and arm an automatic backoff retry.
  Future<void> syncNow() async {
    if (!settings.settings.syncEnabled || _syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      await backend.initialize();
      await backend.signIn();
      final code = settings.settings.householdCode;
      if (code.isEmpty) throw StateError('No household joined.');
      final since =
          settings.settings.lastSyncAt ??
          DateTime.fromMillisecondsSinceEpoch(0).toLocal();

      // 1) Pull remote changes since the last checkpoint.
      final remoteMeds = await backend.pullMedicines(since);
      final remoteDoses = await backend.pullDoses(since);

      // 2) Apply remote changes to the local DB (last writer wins). These
      //    applies never enqueue, so cloud writes don't echo back.
      for (final rm in remoteMeds) {
        final id = rm.medicine.id;
        if (rm.deleted) {
          if (id != null) {
            await medicineRepository.deleteIfExists(id);
            await doseRepository.deleteForMedicine(id);
          }
        } else {
          await medicineRepository.applyRemoteMedicine(rm.medicine);
        }
      }
      for (final rd in remoteDoses) {
        await doseRepository.applyRemoteDose(rd.dose, deleted: rd.deleted);
      }

      // 3) Drain the outbox: push pending local changes (and tombstones).
      final outbox = await syncRepository.pendingOutbox();
      final allMedicines = await medicineRepository.getAll();
      final tombstones = await syncRepository.pendingMedicineTombstones();

      final pushMeds = <RemoteMedicine>[];
      for (final e in outbox) {
        if (e.type != SyncRepository.medicineType) continue;
        final m = await medicineRepository.getById(e.entityId);
        if (m == null || m.id == null) continue; // orphan; pruned below
        pushMeds.add(RemoteMedicine(m, false, m.updatedAt));
      }
      for (final t in tombstones) {
        pushMeds.add(
          RemoteMedicine(
            Medicine(
              id: t.medicineId,
              name: '',
              createdAt: t.updatedAt,
              updatedAt: t.updatedAt,
            ),
            true,
            t.updatedAt,
          ),
        );
      }

      final pushDoses = <RemoteDose>[];
      for (final e in outbox) {
        if (e.type != SyncRepository.doseType) continue;
        final d = await doseRepository.getDose(e.entityId);
        if (d == null || d.id == null) continue; // orphan; pruned below
        pushDoses.add(
          RemoteDose(
            d,
            _nameFor(d.medicineId, allMedicines),
            false,
            d.updatedAt,
          ),
        );
      }

      // Also push dose tombstones (pending dose deletions).
      final doseTombstones = await syncRepository.pendingDoseTombstones();
      for (final t in doseTombstones) {
        pushDoses.add(
          RemoteDose(
            MedicineDose(
              medicineId: t.medicineId,
              scheduledAt: t.scheduledAt,
              updatedAt: t.updatedAt,
            ),
            _nameFor(t.medicineId, allMedicines),
            true,
            t.updatedAt,
          ),
        );
      }

      if (pushMeds.isNotEmpty) await backend.pushMedicines(pushMeds);
      if (pushDoses.isNotEmpty) await backend.pushDoses(pushDoses);

      // 4) Only now can the queue be drained and the checkpoint advanced:
      //    both happen after the backend confirmed the upload.
      await syncRepository.removeOutbox(outbox);
      await syncRepository.pruneOutbox();
      await syncRepository.clearMedicineTombstones([
        for (final t in tombstones) t.medicineId,
      ]);
      await syncRepository.clearDoseTombstones(doseTombstones);

      final syncedAt = DateTime.now();
      await settings.setLastSyncAt(syncedAt);
      _lastSyncAt = syncedAt;
      _lastError = null;
      _resetRetry();

      // 5) Watcher alerts for anything missed in this batch.
      _checkMissed(remoteDoses);

      await onDataChanged?.call();
    } catch (e) {
      _lastError = '$e';
      // Keep the queue; retry sooner with exponential backoff.
      _retryAttempt++;
      _armRetry();
    } finally {
      _syncing = false;
      await _refreshPendingCount();
      notifyListeners();
    }
  }

  /// Watches the household dose stream for missed-dose alerts (watcher role).
  void _startWatch() {
    _watch ??= backend.watchDoses().listen(_checkMissed);
  }

  void _checkMissed(List<RemoteDose> doses) {
    final s = settings.settings;
    if (s.syncRole != 'watcher' || !s.missedAlertsEnabled) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    for (final rd in doses) {
      if (rd.deleted || rd.dose.status != DoseStatus.missed) continue;
      // Only alert for recent misses so the initial full sync doesn't flood
      // the watcher with old history.
      if (rd.dose.scheduledAt.isBefore(cutoff)) continue;
      final key =
          '${rd.dose.medicineId}:${rd.dose.scheduledAt.toIso8601String()}';
      if (!_notifiedMissed.add(key)) continue;
      prefs.setStringList(_notifiedKey, _notifiedMissed.toList());
      final text = ReminderText.from(s.locale, snoozeMinutes: s.snoozeMinutes);
      notifications.showMissedAlert(
        title: text.missedAlertTitle,
        body: text.missedAlertBody(
          rd.medicineName,
          AppDateUtils.timeLabel(rd.dose.scheduledAt, s.locale),
        ),
      );
    }
  }

  String _nameFor(int medicineId, List<Medicine> medicines) {
    for (final m in medicines) {
      if (m.id == medicineId) return m.name;
    }
    return '';
  }

  // ---- Queue maintenance ------------------------------------------------------

  /// Re-queues every medicine/dose changed since the last checkpoint. This is
  /// the safety net that makes the queue self-healing: it catches rows whose
  /// enqueue was lost (upgrade from an older schema, a crash mid-write, a
  /// clock jump that moved `lastSyncAt` into the future). Upserts make it
  /// idempotent, and it is safe because a row updated after our last sync
  /// cannot be older than its remote copy (pulls advance local `updated_at`).
  Future<void> _reconcileOutbox() async {
    final since =
        settings.settings.lastSyncAt ??
        DateTime.fromMillisecondsSinceEpoch(0).toLocal();
    for (final m in await medicineRepository.getAllUpdatedSince(since)) {
      if (m.id != null) {
        await syncRepository.enqueueMedicine(m.id!, m.updatedAt);
      }
    }
    for (final d in await doseRepository.getAllUpdatedSince(since)) {
      if (d.id != null) await syncRepository.enqueueDose(d.id!, d.updatedAt);
    }
    await syncRepository.pruneOutbox();
  }

  Future<void> _refreshPendingCount() async {
    _pendingCount = await syncRepository.countPending();
  }

  // ---- Retry machinery ---------------------------------------------------------

  /// Exponential backoff with jitter, capped at the periodic interval so a
  /// chronically failing backend still only retries at most every 10 minutes.
  Duration _retryDelay() {
    final exponent = _retryAttempt.clamp(0, 8);
    var base = _retryBase * (1 << exponent);
    if (base > _retryMax) base = _retryMax;
    final jitter = 0.8 + 0.4 * _random.nextDouble();
    return Duration(milliseconds: (base.inMilliseconds * jitter).round());
  }

  void _armRetry() {
    _retryTimer?.cancel();
    final delay = _retryDelay();
    _nextRetryAt = DateTime.now().add(delay);
    _retryTimer = Timer(delay, () {
      _nextRetryAt = null;
      unawaited(syncNow());
    });
  }

  void _resetRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _nextRetryAt = null;
    _retryAttempt = 0;
  }

  // ---- Connectivity -------------------------------------------------------------

  Future<void> _startPeriodic() async {
    _timer?.cancel();
    _timer = Timer.periodic(_syncInterval, (_) => unawaited(syncNow()));
    _startWatch();
    await _initConnectivity();
  }

  /// Triggers an immediate sync when the network comes back after being
  /// offline. The initial state is recorded without syncing.
  Future<void> _initConnectivity() async {
    final connectivity = this.connectivity;
    if (connectivity == null) return;
    try {
      final results = await connectivity.checkConnectivity();
      _wasOffline = !_anyOnline(results);
      _connectivitySub = connectivity.onConnectivityChanged
          .distinct() // deduplicate rapid-fire events from the same transition
          .listen((results) {
            final online = _anyOnline(results);
            if (online && _wasOffline && settings.settings.syncEnabled) {
              unawaited(syncNow());
            }
            _wasOffline = !online;
          });
    } catch (_) {
      // Plugin unavailable (tests/desktop): connectivity retry stays off.
    }
  }

  bool _anyOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  void dispose() {
    _timer?.cancel();
    _retryTimer?.cancel();
    _watch?.cancel();
    _connectivitySub?.cancel();
    super.dispose();
  }
}
