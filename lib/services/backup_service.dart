import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/medicine.dart';
import '../data/repositories/medicine_repository.dart';

/// Backup and restore all app data (medicines, doses, settings, vitals)
/// as a single JSON file.
class BackupService {
  MedicineRepository? _medicineRepo;

  /// Set the medicine repository for database access.
  void setMedicineRepository(MedicineRepository repo) {
    _medicineRepo = repo;
  }

  /// Exports all app data to a JSON file.
  /// Returns the file path of the created backup.
  Future<String> createBackup() async {
    final data = <String, dynamic>{};

    // 1. Medicines from repository
    try {
      if (_medicineRepo != null) {
        final medicines = await _medicineRepo!.getAll();
        data['medicines'] = medicines.map((m) => m.toMap()).toList();
      } else {
        data['medicines'] = [];
      }
    } catch (e) {
      debugPrint('Backup: failed to read medicines: $e');
      data['medicines'] = [];
    }

    // 2. SharedPreferences (settings, vitals, etc.)
    final prefs = await SharedPreferences.getInstance();
    final allPrefs = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      if (value is String) {
        allPrefs[key] = value;
      } else if (value is int) {
        allPrefs[key] = value;
      } else if (value is double) {
        allPrefs[key] = value;
      } else if (value is bool) {
        allPrefs[key] = value;
      } else if (value is List<String>) {
        allPrefs[key] = value;
      }
    }
    data['preferences'] = allPrefs;

    // 3. Metadata
    data['backup_version'] = 1;
    data['created_at'] = DateTime.now().toIso8601String();
    data['app_version'] = '1.0.0';

    // Write to file
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/dosewise_backup_$timestamp.json');
    await file.writeAsString(jsonEncode(data));

    debugPrint('Backup created: ${file.path}');
    return file.path;
  }

  /// Restores app data from a backup JSON file.
  /// Returns true on success.
  Future<bool> restoreBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final jsonString = await file.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      // 1. Restore medicines to repository
      if (data['medicines'] != null && _medicineRepo != null) {
        final medicines = (data['medicines'] as List)
            .map((m) => Medicine.fromMap(m as Map<String, Object?>))
            .toList();
        for (final med in medicines) {
          if (med.id != null) {
            await _medicineRepo!.update(med);
          } else {
            await _medicineRepo!.insert(med);
          }
        }
      }

      // 2. Restore SharedPreferences
      if (data['preferences'] != null) {
        final prefs = await SharedPreferences.getInstance();
        final allPrefs = data['preferences'] as Map<String, dynamic>;
        for (final entry in allPrefs.entries) {
          final value = entry.value;
          if (value is String) {
            await prefs.setString(entry.key, value);
          } else if (value is int) {
            await prefs.setInt(entry.key, value);
          } else if (value is double) {
            await prefs.setDouble(entry.key, value);
          } else if (value is bool) {
            await prefs.setBool(entry.key, value);
          } else if (value is List) {
            await prefs.setStringList(
              entry.key,
              value.map((e) => e.toString()).toList(),
            );
          }
        }
      }

      debugPrint('Backup restored successfully');
      return true;
    } catch (e) {
      debugPrint('Backup restore failed: $e');
      return false;
    }
  }

  /// Lists all available backup files.
  Future<List<BackupInfo>> listBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final files = dir.listSync().whereType<File>().where(
      (f) => f.path.contains('dosewise_backup_') && f.path.endsWith('.json'),
    ).toList();

    final backups = <BackupInfo>[];
    for (final file in files) {
      try {
        final stat = await file.stat();
        final name = file.path.split(Platform.pathSeparator).last;
        backups.add(BackupInfo(
          path: file.path,
          name: name,
          size: stat.size,
          createdAt: stat.modified,
        ));
      } catch (_) {}
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  /// Deletes a backup file.
  Future<void> deleteBackup(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

class BackupInfo {
  final String path;
  final String name;
  final int size;
  final DateTime createdAt;

  const BackupInfo({
    required this.path,
    required this.name,
    required this.size,
    required this.createdAt,
  });

  String get sizeLabel {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
