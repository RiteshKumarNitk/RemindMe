import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart'
    if (dart.library.io) 'database_factory_stub.dart'
    as db_web;

/// Local SQLite database. Injectable factory/path so unit tests can run on
/// the desktop via sqflite_common_ffi. On web, sqflite has no native plugin,
/// so the FFI (WASM) factory is used instead.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory,
      _path = path;

  static const String dbFileName = 'medireminder.db';
  static const int _version = 5;

  /// Pending-changes queue for cloud sync (v4). One row per entity that has
  /// changed locally and not yet been uploaded; rows are removed after a
  /// successful push.
  static const String _outboxSchema = '''
    CREATE TABLE sync_outbox (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      entity_type TEXT NOT NULL,
      entity_id INTEGER NOT NULL,
      updated_at TEXT NOT NULL,
      UNIQUE (entity_type, entity_id)
    )
  ''';

  final DatabaseFactory? _factory;
  final String? _path;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final factory =
        _factory ?? (kIsWeb ? db_web.databaseFactoryFfiWeb : databaseFactory);
    final path = _path ?? '${await factory.getDatabasesPath()}/$dbFileName';
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE medicine_doses ADD COLUMN updated_at TEXT',
            );
          }
          if (oldVersion < 3) {
            await db.execute('''
              CREATE TABLE sync_tombstones (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                medicine_key INTEGER NOT NULL,
                updated_at TEXT NOT NULL
              )
            ''');
          }
          if (oldVersion < 4) {
            await db.execute(_outboxSchema);
          }
          if (oldVersion < 5) {
            await db.execute('''
              CREATE TABLE sync_dose_tombstones (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                medicine_id INTEGER NOT NULL,
                scheduled_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE (medicine_id, scheduled_at)
              )
            ''');
          }
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE medicines (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              dosage TEXT NOT NULL DEFAULT '',
              dosage_unit TEXT NOT NULL DEFAULT '',
              notes TEXT NOT NULL DEFAULT '',
              food_instruction TEXT NOT NULL DEFAULT 'none',
              frequency TEXT NOT NULL DEFAULT 'daily',
              selected_days TEXT NOT NULL DEFAULT '',
              once_date TEXT,
              active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE medicine_schedules (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              medicine_id INTEGER NOT NULL,
              hour INTEGER NOT NULL,
              minute INTEGER NOT NULL,
              enabled INTEGER NOT NULL DEFAULT 1,
              FOREIGN KEY (medicine_id) REFERENCES medicines (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('''
            CREATE TABLE medicine_doses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              medicine_id INTEGER NOT NULL,
              scheduled_at TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'pending',
              taken_at TEXT,
              skipped_at TEXT,
              snoozed_until TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE (medicine_id, scheduled_at)
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_doses_scheduled ON medicine_doses (scheduled_at)',
          );
          await db.execute('''
            CREATE TABLE sync_tombstones (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              medicine_key INTEGER NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute(_outboxSchema);
          await db.execute('''
            CREATE TABLE sync_dose_tombstones (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              medicine_id INTEGER NOT NULL,
              scheduled_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              UNIQUE (medicine_id, scheduled_at)
            )
          ''');
        },
      ),
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
