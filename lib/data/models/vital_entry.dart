/// Types of vitals that can be tracked.
enum VitalType {
  bloodPressure,
  bloodSugar,
  weight,
  temperature,
  heartRate;

  String get displayName {
    switch (this) {
      case VitalType.bloodPressure:
        return 'Blood Pressure';
      case VitalType.bloodSugar:
        return 'Blood Sugar';
      case VitalType.weight:
        return 'Weight';
      case VitalType.temperature:
        return 'Temperature';
      case VitalType.heartRate:
        return 'Heart Rate';
    }
  }

  String get unit {
    switch (this) {
      case VitalType.bloodPressure:
        return 'mmHg';
      case VitalType.bloodSugar:
        return 'mg/dL';
      case VitalType.weight:
        return 'kg';
      case VitalType.temperature:
        return '°F';
      case VitalType.heartRate:
        return 'bpm';
    }
  }
}

/// A single vital sign reading.
class VitalEntry {
  final int? id;
  final VitalType type;
  final double value;
  final double? value2; // For BP: diastolic value
  final DateTime recordedAt;
  final String? notes;

  const VitalEntry({
    this.id,
    required this.type,
    required this.value,
    this.value2,
    required this.recordedAt,
    this.notes,
  });

  /// Display value (e.g., "120/80" for BP)
  String get displayValue {
    switch (type) {
      case VitalType.bloodPressure:
        return '${value.round()}/${(value2 ?? 0).round()}';
      case VitalType.weight:
        return value.toStringAsFixed(1);
      default:
        return value.round().toString();
    }
  }

  /// Status based on normal ranges
  VitalStatus get status {
    switch (type) {
      case VitalType.bloodPressure:
        final sys = value;
        final dia = value2 ?? 0;
        if (sys < 120 && dia < 80) return VitalStatus.normal;
        if (sys < 140 && dia < 90) return VitalStatus.elevated;
        return VitalStatus.high;
      case VitalType.bloodSugar:
        if (value < 100) return VitalStatus.normal;
        if (value < 126) return VitalStatus.elevated;
        return VitalStatus.high;
      case VitalType.weight:
        return VitalStatus.normal; // No auto-assessment for weight
      case VitalType.temperature:
        if (value >= 97.0 && value <= 99.0) return VitalStatus.normal;
        return VitalStatus.elevated;
      case VitalType.heartRate:
        if (value >= 60 && value <= 100) return VitalStatus.normal;
        return VitalStatus.elevated;
    }
  }

  VitalEntry copyWith({
    int? id,
    VitalType? type,
    double? value,
    double? value2,
    DateTime? recordedAt,
    String? notes,
  }) {
    return VitalEntry(
      id: id ?? this.id,
      type: type ?? this.type,
      value: value ?? this.value,
      value2: value2 ?? this.value2,
      recordedAt: recordedAt ?? this.recordedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type.name,
      'value': value,
      'value2': value2,
      'recorded_at': recordedAt.toIso8601String(),
      'notes': notes,
    };
  }

  static VitalEntry fromMap(Map<String, Object?> map) {
    return VitalEntry(
      id: map['id'] as int?,
      type: VitalType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => VitalType.bloodPressure,
      ),
      value: (map['value'] as num).toDouble(),
      value2: (map['value2'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
      notes: map['notes'] as String?,
    );
  }
}

enum VitalStatus { normal, elevated, high }
