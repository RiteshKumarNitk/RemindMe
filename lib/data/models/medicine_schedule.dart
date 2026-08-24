import 'package:flutter/material.dart';

/// A reminder time (HH:mm) belonging to a medicine.
class MedicineSchedule {
  final int? id;
  final int medicineId;
  final int hour;
  final int minute;
  final bool enabled;

  const MedicineSchedule({
    this.id,
    required this.medicineId,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  TimeOfDay get time => TimeOfDay(hour: hour, minute: minute);

  MedicineSchedule copyWith({bool? enabled}) {
    return MedicineSchedule(
      id: id,
      medicineId: medicineId,
      hour: hour,
      minute: minute,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'medicine_id': medicineId,
      'hour': hour,
      'minute': minute,
      'enabled': enabled ? 1 : 0,
    };
  }

  static MedicineSchedule fromMap(Map<String, Object?> map) {
    return MedicineSchedule(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      hour: map['hour'] as int,
      minute: map['minute'] as int,
      enabled: (map['enabled'] as int? ?? 1) == 1,
    );
  }
}
