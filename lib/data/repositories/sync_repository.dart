import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';

/// A medicine deletion recorded for upload to the cloud (tombstones).
class MedicineTombstone {
  final int medicineId;
  final DateTime updatedAt;
  const MedicineTombstone(this.medicineId, this.updatedAt);
}

/// A pending dose deletion recorded for cloud propagation. The composite key
/// is (medicine_id, scheduled_at) — the identity used across devices.
class DoseTombstone {
  final int medicineId;
  final DateTime scheduledAt;
  final DateTime updatedAt;
  const DoseTombstone(this.medicineId, this.scheduledAt, this.updatedAt);
}

/// One locally-changed entity waiting to be pushed to the cloud. Entries are
/// removed only after the push succeeds, so a persistent queue survives
/// network outages, app restarts and device reboots.
class OutboxEntry {
  final String type;
  final int entityId;
  final DateTime updatedAt;
  const OutboxEntry(this.type, this.entityId, this.updatedAt);
}

/// Persists local deletions and pending changes so the sync layer can
/// propagate them. Tombstones and outbox entries are removed once uploaded.
class SyncRepository {
  SyncRepository(this._db);

  static const String medicineType = 'medicine';
  static const String doseType = 'dose';

  final AppDatabase _db;

  // ---- Tombstones (medicine deletions) --------------------------------------

  Future<void> addMedicineTombstone(int medicineId) async {
    final db = await _db.database;
    await db.insert('sync_tombstones', {
      'medicine_key': medicineId,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<MedicineTombstone>> pendingMedicineTombstones() async {
    final db = await _db.database;
    final rows = await db.query('sync_tombstones', orderBy: 'updated_at');
    return rows
        .map(
          (r) => MedicineTombstone(
            r['medicine_key'] as int,
            DateTime.parse(r['updated_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> clearMedicineTombstones(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await _db.database;
    await db.delete(
      'sync_tombstones',
      where: 'medicine_key IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  // ---- Dose tombstones (pending dose deletions) -------------------------------

  /// Records a pending dose deletion for cloud propagation. The composite
  /// key is (medicine_id, scheduled_at) — the same identity used for doses
  /// across devices.
  Future<void> addDoseTombstone(int medicineId, DateTime scheduledAt) async {
    final db = await _db.database;
    await db.insert('sync_dose_tombstones', {
      'medicine_id': medicineId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<DoseTombstone>> pendingDoseTombstones() async {
    final db = await _db.database;
    final rows = await db.query('sync_dose_tombstones', orderBy: 'updated_at');
    return rows
        .map(
          (r) => DoseTombstone(
            r['medicine_id'] as int,
            DateTime.parse(r['scheduled_at'] as String),
            DateTime.parse(r['updated_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> clearDoseTombstones(List<DoseTombstone> tombstones) async {
    if (tombstones.isEmpty) return;
    final db = await _db.database;
    final clauses = <String>[];
    final args = <Object?>[];
    for (final t in tombstones) {
      clauses.add('(medicine_id = ? AND scheduled_at = ?)');
      args.add(t.medicineId);
      args.add(t.scheduledAt.toIso8601String());
    }
    await db.delete(
      'sync_dose_tombstones',
      where: clauses.join(' OR '),
      whereArgs: args,
    );
  }

  // ---- Outbox (pending medicine/dose changes) --------------------------------

  /// Queues a medicine change for upload. Upserts so only the latest state of
  /// an entity is ever queued.
  Future<void> enqueueMedicine(int id, DateTime updatedAt) =>
      _enqueue(medicineType, id, updatedAt);

  /// Queues a dose change for upload.
  Future<void> enqueueDose(int id, DateTime updatedAt) =>
      _enqueue(doseType, id, updatedAt);

  Future<void> _enqueue(String type, int id, DateTime updatedAt) async {
    final db = await _db.database;
    await db.insert('sync_outbox', {
      'entity_type': type,
      'entity_id': id,
      'updated_at': updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<OutboxEntry>> pendingOutbox() async {
    final db = await _db.database;
    final rows = await db.query('sync_outbox', orderBy: 'updated_at');
    return [
      for (final r in rows)
        OutboxEntry(
          r['entity_type'] as String,
          r['entity_id'] as int,
          DateTime.parse(r['updated_at'] as String),
        ),
    ];
  }

  /// Removes entries that were pushed successfully. Unknown entries are
  /// ignored.
  Future<void> removeOutbox(List<OutboxEntry> entries) async {
    if (entries.isEmpty) return;
    final db = await _db.database;
    final clauses = <String>[];
    final args = <Object?>[];
    for (final e in entries) {
      clauses.add('(entity_type = ? AND entity_id = ?)');
      args.add(e.type);
      args.add(e.entityId);
    }
    await db.delete(
      'sync_outbox',
      where: clauses.join(' OR '),
      whereArgs: args,
    );
  }

  /// Drops outbox entries whose entity no longer exists locally (e.g. a
  /// medicine deleted after a newer edit was queued). Deletes are propagated
  /// through the tombstone table instead.
  Future<void> pruneOutbox() async {
    final db = await _db.database;
    await db.execute('''
      DELETE FROM sync_outbox
       WHERE (entity_type = '$medicineType' AND
              entity_id NOT IN (SELECT id FROM medicines))
          OR (entity_type = '$doseType' AND
              entity_id NOT IN (SELECT id FROM medicine_doses))
    ''');
  }

  Future<void> clearOutbox() async {
    final db = await _db.database;
    await db.delete('sync_outbox');
  }

  /// Number of changes waiting to be uploaded (outbox + tombstones).
  Future<int> countPending() async {
    final db = await _db.database;
    final outbox = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_outbox'),
    );
    final tombs = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM sync_tombstones'),
    );
    return (outbox ?? 0) + (tombs ?? 0);
  }
}
