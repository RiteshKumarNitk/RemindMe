import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/dose_status.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/medicine_dose.dart';
import '../../data/models/medicine_frequency.dart';
import '../../data/models/medicine_schedule.dart';
import 'remote_backend.dart';

/// Firebase implementation of [RemoteBackend].
///
/// Data layout:
///   households/{id}                      { createdAt, ownerUid }
///   households/{id}/members/{uid}        { userId, householdId, role, permissions, createdAt, fcmToken? }
///   households/{id}/medicines/{id}       medicine snapshot (tombstone via `deleted`)
///   households/{id}/doses/{medId_ts}     dose snapshot (identity: medicineId + scheduledAt)
///   invitations/{sha256(token)}          { householdId, creatorUid, creatorName, expiresAt, used }
///
/// The household id is an opaque short code used only as a document key and a
/// human-shareable handle. It is NOT a security boundary — members-only reads
/// and owner-only removal are enforced by Firestore rules against the
/// members subcollection, and joining requires a single-use invitation token.
///
/// All timestamps travel as UTC ISO-8601 strings so lexicographic ordering in
/// Firestore queries is chronological regardless of device time zone.
class FirebaseBackend implements RemoteBackend {
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

  String? _householdCode;

  /// Lazily-resolved Firestore handle. Touching `.instance` before
  /// [initialize] throws on platforms without auto-init (e.g. web, where
  /// there is no google-services.json), so the constructor must never access
  /// it — doing so crashed startup before [initialize] could report the
  /// unconfigured state gracefully.
  FirebaseFirestore get _fs => _firestore ??= FirebaseFirestore.instance;

  /// Lazily-resolved auth handle (same rationale as [_fs]).
  FirebaseAuth get _authRef => _auth ??= FirebaseAuth.instance;

  @override
  Future<void> initialize() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      // Force-resolution inside the guard: surfaces a missing/unusable
      // config here (caught below) instead of at first use.
      _fs;
      _authRef;
    } catch (e) {
      throw StateError(
        'Firebase is not configured. Add android/app/google-services.json '
        'from your Firebase project (see README). ($e)',
      );
    }
  }

  @override
  Future<void> signIn() async {
    if (_authRef.currentUser == null) {
      await _authRef.signInAnonymously();
    }
  }

  @override
  Future<String> createHousehold() async {
    final uid = _requireUid();
    final now = DateTime.now().toUtc().toIso8601String();

    // Collision-safe creation: a transaction that only writes when the id is
    // free, retried with a fresh id on the (astronomically rare) clash. Never
    // a bare set() — that could silently overwrite someone else's household.
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final doc = _fs.collection('households').doc(code);
      try {
        final created = await _fs.runTransaction<bool>((txn) async {
          final snap = await txn.get(doc);
          if (snap.exists) return false;
          txn.set(doc, {'createdAt': now, 'ownerUid': uid});
          txn.set(doc.collection('members').doc(uid), {
            'userId': uid,
            'householdId': code,
            'role': 'owner',
            'permissions': {
              'shareMedicines': false,
              'shareMissedAlerts': false,
            },
            'createdAt': now,
          });
          return true;
        });
        if (created) {
          _householdCode = code;
          return code;
        }
      } on FirebaseException catch (e) {
        if (e.code != 'aborted' && e.code != 'failed-precondition') rethrow;
      }
    }
    throw StateError('Could not create a household. Please try again.');
  }

  @override
  Future<String> joinHousehold(String code) async {
    // The QR flow (InvitationService.acceptInvitation) already wrote this
    // user's membership record inside a transaction. This just points the
    // local sync at the household and confirms the membership stuck.
    final normalized = _normalizeCode(code);
    final uid = _requireUid();
    final member = await _fs
        .collection('households')
        .doc(normalized)
        .collection('members')
        .doc(uid)
        .get();
    if (!member.exists) {
      throw StateError(
        'You are not a member of this family. Scan the QR code again.',
      );
    }
    _householdCode = normalized;
    return normalized;
  }

  @override
  Future<String?> currentHousehold() async => _householdCode;

  @override
  Future<void> attachPushToken() async {
    try {
      final code = _householdCode;
      final uid = _authRef.currentUser?.uid;
      if (code == null || uid == null) return;
      // getToken() can block for a very long time on emulators / devices
      // without Play Services — cap it so it never stalls sync setup.
      final token = await FirebaseMessaging.instance.getToken().timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );
      if (token == null) return;
      String tzName;
      try {
        tzName = tz.local.name;
      } catch (_) {
        tzName = 'unknown';
      }
      await _fs
          .collection('households')
          .doc(code)
          .collection('members')
          .doc(uid)
          .set({
        'fcmToken': token,
        // For the sendScheduledReminders delivery log only — dose fire times
        // are absolute UTC instants, so this is not used for timing.
        'timezone': tzName,
        'platform': 'android',
        'tokenUpdatedAt': DateTime.now().toUtc().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Push is best-effort; sync keeps working without it.
    }
  }

  // ---- Writes ---------------------------------------------------------------

  @override
  Future<void> pushMedicines(List<RemoteMedicine> items) async {
    final code = _requireHousehold();
    final batch = _fs.batch();
    for (final item in items) {
      final med = item.medicine;
      batch.set(
        _fs
            .collection('households')
            .doc(code)
            .collection('medicines')
            .doc('${med.id}'),
        {
          'name': med.name,
          'dosage': med.dosage,
          'dosage_unit': med.dosageUnit,
          'notes': med.notes,
          'food_instruction': med.foodInstruction.name,
          'frequency': med.frequency.name,
          'selected_days': med.selectedDays,
          'once_date': med.onceDate == null
              ? null
              : '${med.onceDate!.year.toString().padLeft(4, '0')}-'
                    '${med.onceDate!.month.toString().padLeft(2, '0')}-'
                    '${med.onceDate!.day.toString().padLeft(2, '0')}',
          'active': med.active,
          'schedules': [
            for (final s in med.schedules)
              {'hour': s.hour, 'minute': s.minute, 'enabled': s.enabled},
          ],
          'updated_at': item.updatedAt.toUtc().toIso8601String(),
          'deleted': item.deleted,
        },
      );
    }
    await batch.commit();
  }

  @override
  Future<void> pushDoses(List<RemoteDose> items) async {
    final code = _requireHousehold();
    final batch = _fs.batch();
    for (final item in items) {
      final d = item.dose;
      batch.set(
        _fs
            .collection('households')
            .doc(code)
            .collection('doses')
            .doc(_doseDocId(d.medicineId, d.scheduledAt)),
        {
          'medicine_id': d.medicineId,
          'scheduled_at': d.scheduledAt.toUtc().toIso8601String(),
          'status': d.status.name,
          'taken_at': d.takenAt?.toUtc().toIso8601String(),
          'skipped_at': d.skippedAt?.toUtc().toIso8601String(),
          'snoozed_until': d.snoozedUntil?.toUtc().toIso8601String(),
          'medicine_name': item.medicineName,
          'updated_at': item.updatedAt.toUtc().toIso8601String(),
          'deleted': item.deleted,
        },
      );
    }
    await batch.commit();
  }

  // ---- Reads ----------------------------------------------------------------

  @override
  Future<List<RemoteMedicine>> pullMedicines(DateTime since) async {
    final code = _requireHousehold();
    final snap = await _fs
        .collection('households')
        .doc(code)
        .collection('medicines')
        .where('updated_at', isGreaterThan: since.toUtc().toIso8601String())
        .get();
    return snap.docs.map(_medicineFromDoc).toList();
  }

  @override
  Future<List<RemoteDose>> pullDoses(DateTime since) async {
    final code = _requireHousehold();
    final snap = await _fs
        .collection('households')
        .doc(code)
        .collection('doses')
        .where('updated_at', isGreaterThan: since.toUtc().toIso8601String())
        .get();
    return snap.docs.map(_doseFromDoc).toList();
  }

  @override
  Stream<List<RemoteDose>> watchDoses() {
    final code = _requireHousehold();
    return _fs
        .collection('households')
        .doc(code)
        .collection('doses')
        .snapshots()
        .map((snap) => snap.docs.map(_doseFromDoc).toList());
  }

  @override
  Future<void> dispose() async {
    // Firebase handles its own connection lifecycle.
  }

  // ---- Conversions -----------------------------------------------------------

  RemoteMedicine _medicineFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final id = int.tryParse(doc.id);
    final updatedAt = _parseTime(data['updated_at'] as String?);
    if (id == null) {
      return RemoteMedicine(
        _emptyMedicine(),
        data['deleted'] == true,
        updatedAt ?? DateTime.now(),
      );
    }
    final scheduleData = (data['schedules'] as List<dynamic>? ?? const []);
    final medicine = Medicine(
      id: id,
      name: (data['name'] as String?) ?? '',
      dosage: (data['dosage'] as String?) ?? '',
      dosageUnit: (data['dosage_unit'] as String?) ?? '',
      notes: (data['notes'] as String?) ?? '',
      foodInstruction: FoodInstruction.from(
        (data['food_instruction'] as String?) ?? 'none',
      ),
      frequency: MedicineFrequency.from(
        (data['frequency'] as String?) ?? 'daily',
      ),
      selectedDays: [
        for (final d in (data['selected_days'] as List<dynamic>? ?? const []))
          d as int,
      ],
      onceDate: data['once_date'] == null
          ? null
          : DateTime.tryParse(data['once_date'] as String),
      active: data['active'] == true,
      createdAt: _parseTime(data['created_at'] as String?) ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
      schedules: [
        for (final s in scheduleData)
          MedicineSchedule(
            medicineId: id,
            hour: ((s['hour'] as num?)?.toInt() ?? 0),
            minute: ((s['minute'] as num?)?.toInt() ?? 0),
            enabled: s['enabled'] != false,
          ),
      ],
    );
    return RemoteMedicine(
      medicine,
      data['deleted'] == true,
      updatedAt ?? DateTime.now(),
    );
  }

  RemoteDose _doseFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final updatedAt = _parseTime(data['updated_at'] as String?);
    final dose = MedicineDose(
      medicineId: (data['medicine_id'] as num?)?.toInt() ?? 0,
      scheduledAt:
          _parseTime(data['scheduled_at'] as String?) ?? DateTime.now(),
      status: _statusFrom(data['status'] as String?),
      takenAt: _parseTime(data['taken_at'] as String?),
      skippedAt: _parseTime(data['skipped_at'] as String?),
      snoozedUntil: _parseTime(data['snoozed_until'] as String?),
      createdAt: _parseTime(data['created_at'] as String?) ?? DateTime.now(),
      updatedAt: updatedAt,
    );
    return RemoteDose(
      dose,
      (data['medicine_name'] as String?) ?? '',
      data['deleted'] == true,
      updatedAt ?? DateTime.now(),
    );
  }

  Medicine _emptyMedicine() => Medicine(
    id: 0,
    name: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  // ---- Helpers ---------------------------------------------------------------

  String _requireHousehold() {
    final code = _householdCode;
    if (code == null) {
      throw StateError('No household joined. Enable sync first.');
    }
    return code;
  }

  String _requireUid() {
    final uid = _authRef.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }
    return uid;
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _normalizeCode(String code) =>
      code.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  String _doseDocId(int medicineId, DateTime scheduledAt) =>
      '${medicineId}_${scheduledAt.millisecondsSinceEpoch}';

  DateTime? _parseTime(String? iso) =>
      iso == null ? null : DateTime.parse(iso).toLocal();

  DoseStatus _statusFrom(String? value) => DoseStatus.from(value ?? 'pending');
}
