import '../database/app_database.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import 'sync_repository.dart';

/// Persists medicines and their reminder schedules.
class MedicineRepository {
  /// [sync] is the optional outbox used to queue local changes for cloud
  /// sync. When null (or in tests that don't exercise sync) nothing is
  /// enqueued.
  MedicineRepository(this._db, {SyncRepository? sync}) : _sync = sync;

  final AppDatabase _db;
  final SyncRepository? _sync;

  Future<List<Medicine>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('medicines', orderBy: 'name COLLATE NOCASE');
    final medicines = rows.map(Medicine.fromMap).toList();
    final schedules = await _allSchedules();
    return [
      for (final m in medicines)
        m.copyWith(
          schedules: schedules.where((s) => s.medicineId == m.id).toList(),
        ),
    ];
  }

  Future<Medicine?> getById(int id) async {
    final all = await getAll();
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }

  Future<Medicine?> getByName(String name) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicines',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return getById(rows.first['id'] as int);
  }

  /// Inserts the medicine and its schedules in a transaction.
  /// Returns the new medicine id.
  Future<int> insert(Medicine medicine) async {
    final db = await _db.database;
    final id = await db.transaction((txn) async {
      final newId = await txn.insert('medicines', medicine.toMap());
      for (final s in medicine.schedules) {
        await txn.insert('medicine_schedules', {
          ...s.toMap(),
          'medicine_id': newId,
        });
      }
      return newId;
    });
    await _sync?.enqueueMedicine(id, medicine.updatedAt);
    return id;
  }

  /// Updates the medicine row and replaces its schedules.
  Future<void> update(Medicine medicine) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'medicines',
        medicine.toMap(),
        where: 'id = ?',
        whereArgs: [medicine.id],
      );
      await txn.delete(
        'medicine_schedules',
        where: 'medicine_id = ?',
        whereArgs: [medicine.id],
      );
      for (final s in medicine.schedules) {
        await txn.insert('medicine_schedules', {
          ...s.toMap(),
          'medicine_id': medicine.id,
        });
      }
    });
    final id = medicine.id;
    if (id != null) await _sync?.enqueueMedicine(id, medicine.updatedAt);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteIfExists(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicines',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
    }
  }

  /// All medicines updated after [since] (used to push local changes).
  /// Uses a SQL WHERE filter instead of fetching all + filtering in Dart.
  Future<List<Medicine>> getAllUpdatedSince(DateTime since) async {
    final db = await _db.database;
    final rows = await db.query(
      'medicines',
      where: 'updated_at > ?',
      whereArgs: [since.toIso8601String()],
      orderBy: 'name COLLATE NOCASE',
    );
    final schedules = await _allSchedules();
    return [
      for (final m in rows.map(Medicine.fromMap))
        m.copyWith(
          schedules: schedules.where((s) => s.medicineId == m.id).toList(),
        ),
    ];
  }

  /// Applies a remote medicine. The medicine id is the stable key across
  /// devices. A newer remote wins over local state; schedules are replaced.
  Future<void> applyRemoteMedicine(Medicine remote) async {
    final db = await _db.database;
    final id = remote.id;
    if (id == null) return;
    final existing = await db.query(
      'medicines',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.transaction((txn) async {
        await txn.insert('medicines', remote.toMap());
        for (final s in remote.schedules) {
          await txn.insert('medicine_schedules', {
            ...s.toMap(),
            'medicine_id': id,
          });
        }
      });
      return;
    }
    final local = Medicine.fromMap(existing.first);
    if (!remote.updatedAt.isAfter(local.updatedAt)) return;
    await db.transaction((txn) async {
      await txn.update(
        'medicines',
        remote.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'medicine_schedules',
        where: 'medicine_id = ?',
        whereArgs: [id],
      );
      for (final s in remote.schedules) {
        await txn.insert('medicine_schedules', {
          ...s.toMap(),
          'medicine_id': id,
        });
      }
    });
  }

  Future<void> setActive(int id, bool active) async {
    final now = DateTime.now();
    final db = await _db.database;
    await db.update(
      'medicines',
      {'active': active ? 1 : 0, 'updated_at': now.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _sync?.enqueueMedicine(id, now);
  }

  Future<List<MedicineSchedule>> _allSchedules() async {
    final db = await _db.database;
    final rows = await db.query('medicine_schedules', orderBy: 'hour, minute');
    return rows.map(MedicineSchedule.fromMap).toList();
  }
}
