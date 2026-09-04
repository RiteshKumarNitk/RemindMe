import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages pill photos stored in the app's documents directory.
/// Photos are named by medicine ID for easy lookup.
class PillPhotoService {
  static const String _folderName = 'pill_photos';

  /// Returns the directory where pill photos are stored.
  Future<Directory> get _photosDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_folderName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Saves a photo for a medicine. Returns the saved file path.
  Future<String?> savePhoto({
    required int medicineId,
    required File sourceFile,
  }) async {
    try {
      final dir = await _photosDir;
      final ext = sourceFile.path.split('.').last.toLowerCase();
      final fileName = 'med_${medicineId}.$ext';
      final targetPath = '${dir.path}/$fileName';

      // Delete old photo if exists
      await deletePhoto(medicineId);

      // Copy the file
      await sourceFile.copy(targetPath);
      debugPrint('PillPhotoService: saved $targetPath');
      return targetPath;
    } catch (e) {
      debugPrint('PillPhotoService: save failed: $e');
      return null;
    }
  }

  /// Returns the photo file path for a medicine, or null if none exists.
  Future<String?> getPhotoPath(int medicineId) async {
    try {
      final dir = await _photosDir;
      // Check common extensions
      for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
        final file = File('${dir.path}/med_${medicineId}.$ext');
        if (await file.exists()) {
          return file.path;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Deletes the photo for a medicine.
  Future<void> deletePhoto(int medicineId) async {
    try {
      final dir = await _photosDir;
      for (final ext in ['jpg', 'jpeg', 'png', 'webp']) {
        final file = File('${dir.path}/med_${medicineId}.$ext');
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
  }

  /// Returns a File object if a photo exists, null otherwise.
  Future<File?> getPhotoFile(int medicineId) async {
    final path = await getPhotoPath(medicineId);
    if (path == null) return null;
    return File(path);
  }
}
