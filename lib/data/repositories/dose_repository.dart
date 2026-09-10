import '../database/app_database.dart';
import '../models/adherence_stats.dart';
import '../models/dose_entry.dart';
import '../models/dose_status.dart';
import '../models/food_instruction.dart';
import '../models/medicine.dart';
import '../models/medicine_dose.dart';
import '../models/medicine_frequency.dart';
import 'sync_repository.dart';

/// Persists dose occurrences and their outcomes.
class DoseRepository {
  /// [sync] is the optional outbox used to queue local changes for cloud
  /// sync. When null (or in tests that don't exercise sync) nothing is
  /// enqueued. Remote applies never enqueue, so cloud writes don't echo back.
  DoseRepository(this._db, {SyncRepository? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncRepository? _sync;

  static const _joinSelect = '''
    SELECT d.id AS dose_id, d.medicine_id, d.scheduled_at, d.status,
           d.taken_at, d.skipped_at, d.snoozed_until,
           d.created_at AS dose_created, d.updated_at AS dose_updated,
           m.id AS med_id, m.name, m.dosage, m.dosage_unit, m.notes,
           m.food_instruction, m.frequency, m.selected_days, m.once_date,
           m.active, m.stock_count, m.refill_at,
           m.created_at AS med_created, m.updated_at AS med_updated
    FROM medicine_doses d
    JOIN medicines m ON m.id = d.medicine_id
  ''';

  /// Returns the dose for [scheduledAt], creating a pending one when
  /// missing. Returns `null` when a dose with a final outcome (taken /
  /// skipped / missed) already exists for that time.
  Future<MedicineDose?> ensureDose({
    required int medicineId,
    required DateTime scheduledAt,
  }) async {
    final db = await _db.database;
    final existing = await db.query(
      'medicine_doses',
      where: 'medicine_id = ? AND scheduled_at = ?',
      whereArgs: [medicineId, scheduledAt.toIso8601String()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final dose = MedicineDose.fromMap(existing.first);
      if (dose.status == DoseStatus.pending) return dose;
      return null;
    }
    final dose = MedicineDose(medicineId: medicineId, scheduledAt: scheduledAt);
    final id = await db.insert('medicine_doses', dose.toMap());
    final saved = dose.copyWith(id: id);
    await _sync?.enqueueDose(id, saved.updatedAt);
    return saved;
  }

  Future<MedicineDose?> getDose(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine_doses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MedicineDose.fromMap(rows.first);
  }

  Future<DoseEntry?> getDoseEntry(int id) async {
    final db = await _db.database;
    final rows = await db.rawQuery('$_joinSelect WHERE d.id = ? LIMIT 1', [id]);
    if (rows.isEmpty) return null;
    return _entryFromRow(rows.first);
  }

  /// Doses in [start, end) joined with their medicines, ordered by time.
  Future<List<DoseEntry>> getEntriesBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_joinSelect WHERE d.scheduled_at >= ? AND d.scheduled_at < ? '
      'ORDER BY d.scheduled_at',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return rows.map(_entryFromRow).toList();
  }

  /// All dose rows updated after [since] (used to push local changes).
  Future<List<MedicineDose>> getAllUpdatedSince(DateTime since) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine_doses',
      where: 'updated_at > ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'scheduled_at',
    );
    return rows.map(MedicineDose.fromMap).toList();
  }

  /// Applies a remote dose to the local database. Identity is
  /// (medicineId, scheduledAt). A newer remote wins over local state;
  /// [deleted] tombstones remove the local row.
  Future<void> applyRemoteDose(
    MedicineDose remote, {
    bool deleted = false,
  }) async {
    final db = await _db.database;
    final key = [remote.medicineId, remote.scheduledAt.toIso8601String()];
    final existing = await db.query(
      'medicine_doses',
      where: 'medicine_id = ? AND scheduled_at = ?',
      whereArgs: key,
      limit: 1,
    );
    if (deleted) {
      if (existing.isNotEmpty) {
        await db.delete(
          'medicine_doses',
          where: 'medicine_id = ? AND scheduled_at = ?',
          whereArgs: key,
        );
      }
      return;
    }
    if (existing.isEmpty) {
      // Dose identity across devices is (medicine_id, scheduled_at); never
      // reuse the remote auto-increment id (it can collide locally).
      await db.insert('medicine_doses', remote.copyWith(id: null).toMap());
      return;
    }
    final local = MedicineDose.fromMap(existing.first);
    if (remote.updatedAt.isAfter(local.updatedAt)) {
      await db.update(
        'medicine_doses',
        {
          'status': remote.status.name,
          'taken_at': remote.takenAt?.toIso8601String(),
          'skipped_at': remote.skippedAt?.toIso8601String(),
          'snoozed_until': remote.snoozedUntil?.toIso8601String(),
          'updated_at': remote.updatedAt.toIso8601String(),
        },
        where: 'medicine_id = ? AND scheduled_at = ?',
        whereArgs: key,
      );
    }
  }

  /// Pending doses for a medicine scheduled at or after [from]
  /// (used to cancel/reschedule after edits).
  Future<List<MedicineDose>> getPendingDosesForMedicine(
    int medicineId,
    DateTime from,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine_doses',
      where: 'medicine_id = ? AND scheduled_at >= ? AND status = ?',
      whereArgs: [medicineId, from.toIso8601String(), 'pending'],
    );
    return rows.map(MedicineDose.fromMap).toList();
  }

  /// Restores a dose to a previous status (used by undo).
  Future<void> restorePreviousStatus(
    int id, {
    required DoseStatus status,
    DateTime? takenAt,
    DateTime? skippedAt,
  }) async {
    final now = DateTime.now();
    final db = await _db.database;
    await db.update(
      'medicine_doses',
      {
        'status': status.name,
        'taken_at': takenAt?.toIso8601String(),
        'skipped_at': skippedAt?.toIso8601String(),
        'snoozed_until': null,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _sync?.enqueueDose(id, now);
  }

  /// All pending doses in [start, end). Used by DoseScheduler.sync to
  /// pre-load existing occurrences and avoid N+1 queries.
  Future<List<MedicineDose>> getPendingBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine_doses',
      where: 'scheduled_at >= ? AND scheduled_at < ? AND status = ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String(), 'pending'],
    );
    return rows.map(MedicineDose.fromMap).toList();
  }

  Future<void> _setStatus(
    int id,
    DoseStatus status, {
    String? takenAt,
    String? skippedAt,
  }) async {
    final now = DateTime.now();
    final db = await _db.database;
    await db.update(
      'medicine_doses',
      {
        'status': status.name,
        'taken_at': status == DoseStatus.taken ? (takenAt ?? now.toIso8601String()) : null,
        'skipped_at': status == DoseStatus.skipped ? (skippedAt ?? now.toIso8601String()) : null,
        'snoozed_until': null,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _sync?.enqueueDose(id, now);
  }

  Future<void> markTaken(int id, DateTime at) =>
      _setStatus(id, DoseStatus.taken, takenAt: at.toIso8601String());

  Future<void> markSkipped(int id, DateTime at) =>
      _setStatus(id, DoseStatus.skipped, skippedAt: at.toIso8601String());

  Future<void> markMissed(int id) => _setStatus(id, DoseStatus.missed);

  Future<void> setSnoozedUntil(int id, DateTime until) async {
    final now = DateTime.now();
    final db = await _db.database;
    await db.update(
      'medicine_doses',
      {
        'snoozed_until': until.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _sync?.enqueueDose(id, now);
  }

  /// Marks as missed every pending dose whose (snoozed or original) time
  /// plus the grace period has passed. Returns the number marked.
  Future<int> sweepMissed(Duration grace, DateTime now) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine_doses',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    var count = 0;
    final markedAt = now.toIso8601String();
    final marked = <int>[];
    await db.transaction((txn) async {
      for (final row in rows) {
        final dose = MedicineDose.fromMap(row);
        final effective = dose.snoozedUntil ?? dose.scheduledAt;
        if (effective.add(grace).isBefore(now)) {
          await txn.update(
            'medicine_doses',
            {'status': DoseStatus.missed.name, 'updated_at': markedAt},
            where: 'id = ?',
            whereArgs: [dose.id],
          );
          marked.add(dose.id!);
          count++;
        }
      }
    });
    for (final id in marked) {
      await _sync?.enqueueDose(id, now);
    }
    return count;
  }

  /// Deletes pending future doses for a medicine (used when a medicine is
  /// edited, paused or deleted so stale notifications disappear). Creates
  /// dose tombstones before deletion so the cloud learns about the removal.
  Future<void> deletePendingFrom(int medicineId, DateTime from) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicine_doses',
      columns: ['medicine_id', 'scheduled_at'],
      where: 'medicine_id = ? AND scheduled_at >= ? AND status = ?',
      whereArgs: [medicineId, from.toIso8601String(), 'pending'],
    );
    // Record tombstones before deletion so sync can propagate the removal.
    for (final row in rows) {
      await _sync?.addDoseTombstone(
        row['medicine_id'] as int,
        DateTime.parse(row['scheduled_at'] as String),
      );
    }
    await db.delete(
      'medicine_doses',
      where: 'medicine_id = ? AND scheduled_at >= ? AND status = ?',
      whereArgs: [medicineId, from.toIso8601String(), 'pending'],
    );
  }

  Future<void> deleteForMedicine(int medicineId) async {
    final db = await _db.database;
    await db.delete(
      'medicine_doses',
      where: 'medicine_id = ?',
      whereArgs: [medicineId],
    );
  }

  /// Counts of outcomes over [start, end) using the grace period to derive
  /// the effective status of pending doses.
  Future<AdherenceStats> statsBetween(
    DateTime start,
    DateTime end, {
    required Duration grace,
    required DateTime now,
  }) async {
    final entries = await getEntriesBetween(start, end);
    var stats = const AdherenceStats();
    for (final e in entries) {
      stats = stats.add(e.effectiveStatus(grace, now));
    }
    return stats;
  }

  static DoseEntry _entryFromRow(Map<String, Object?> row) {
    // Construct Medicine from the joined row using aliased columns to avoid
    // ambiguity (dose_id vs medicine id, created_at vs dose created_at).
    final once = row['once_date'] as String?;
    final medicine = Medicine(
      id: row['med_id'] as int?,
      name: (row['name'] as String?) ?? '',
      dosage: (row['dosage'] as String?) ?? '',
      dosageUnit: (row['dosage_unit'] as String?) ?? '',
      notes: (row['notes'] as String?) ?? '',
      foodInstruction: FoodInstruction.from(
        (row['food_instruction'] as String?) ?? 'none',
      ),
      frequency: MedicineFrequency.from(
        (row['frequency'] as String?) ?? 'daily',
      ),
      selectedDays: _decodeDays(row['selected_days'] as String?),
      onceDate: once == null ? null : DateTime.tryParse(once),
      active: (row['active'] as int? ?? 1) == 1,
      stockCount: row['stock_count'] as int?,
      refillAt: row['refill_at'] as int?,
      createdAt: DateTime.parse(row['med_created'] as String),
      updatedAt: DateTime.parse(row['med_updated'] as String),
    );
    final dose = MedicineDose(
      id: row['dose_id'] as int?,
      medicineId: row['medicine_id'] as int,
      scheduledAt: DateTime.parse(row['scheduled_at'] as String),
      status: DoseStatus.from((row['status'] as String?) ?? 'pending'),
      takenAt: row['taken_at'] == null
          ? null
          : DateTime.parse(row['taken_at'] as String),
      skippedAt: row['skipped_at'] == null
          ? null
          : DateTime.parse(row['skipped_at'] as String),
      snoozedUntil: row['snoozed_until'] == null
          ? null
          : DateTime.parse(row['snoozed_until'] as String),
      createdAt: DateTime.parse(row['dose_created'] as String),
      updatedAt: DateTime.parse(row['dose_updated'] as String),
    );
    return DoseEntry(dose, medicine);
  }

  static List<int> _decodeDays(String? value) {
    if (value == null || value.isEmpty) return const [];
    return value
        .split(',')
        .where((s) => s.trim().isNotEmpty)
        .map((s) => int.tryParse(s.trim()) ?? -1)
        .where((d) => d >= DateTime.monday && d <= DateTime.sunday)
        .toList();
  }
}
