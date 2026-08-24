import 'dart:convert';

import '../data/models/medicine.dart';
import '../data/models/medicine_dose.dart';
import '../data/repositories/dose_repository.dart';
import '../data/repositories/medicine_repository.dart';

/// Generates a JSON backup of all medicines and dose history.
/// The backup can be used to restore data on another device.
class ExportService {
  ExportService({
    required this.medicineRepository,
    required this.doseRepository,
  });

  final MedicineRepository medicineRepository;
  final DoseRepository doseRepository;

  /// Generates a JSON string containing all medicines and their dose history.
  Future<String> exportToJson() async {
    final medicines = await medicineRepository.getAll();
    final now = DateTime.now();
    // Export all doses from the last 365 days.
    final start = now.subtract(const Duration(days: 365));
    final end = now.add(const Duration(days: 1));
    final doses = await doseRepository.getEntriesBetween(start, end);

    final data = {
      'exportedAt': now.toIso8601String(),
      'version': 1,
      'medicines': [for (final med in medicines) _medicineToJson(med)],
      'doses': [for (final entry in doses) _doseToJson(entry)],
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Map<String, Object?> _medicineToJson(Medicine med) {
    return {
      'id': med.id,
      'name': med.name,
      'dosage': med.dosage,
      'dosageUnit': med.dosageUnit,
      'notes': med.notes,
      'foodInstruction': med.foodInstruction.name,
      'frequency': med.frequency.name,
      'selectedDays': med.selectedDays,
      'onceDate': med.onceDate?.toIso8601String(),
      'active': med.active,
      'stockCount': med.stockCount,
      'refillAt': med.refillAt,
      'createdAt': med.createdAt.toIso8601String(),
      'updatedAt': med.updatedAt.toIso8601String(),
      'schedules': [
        for (final s in med.schedules)
          {'hour': s.hour, 'minute': s.minute, 'enabled': s.enabled},
      ],
    };
  }

  Map<String, Object?> _doseToJson(dynamic entry) {
    final dose = entry.dose as MedicineDose;
    return {
      'medicineId': dose.medicineId,
      'medicineName': entry.medicine.name,
      'scheduledAt': dose.scheduledAt.toIso8601String(),
      'status': dose.status.name,
      'takenAt': dose.takenAt?.toIso8601String(),
      'skippedAt': dose.skippedAt?.toIso8601String(),
      'createdAt': dose.createdAt.toIso8601String(),
      'updatedAt': dose.updatedAt.toIso8601String(),
    };
  }
}
