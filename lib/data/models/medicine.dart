import 'food_instruction.dart';
import 'medicine_frequency.dart';
import 'medicine_schedule.dart';

/// A medicine with its reminder schedule.
class Medicine {
  final int? id;
  final String name;
  final String dosage;
  final String dosageUnit;
  final String notes;
  final FoodInstruction foodInstruction;
  final MedicineFrequency frequency;

  /// Weekday numbers 1..7 (DateTime.monday..DateTime.sunday) when
  /// [frequency] is [MedicineFrequency.specificDays].
  final List<int> selectedDays;

  /// Single reminder date when [frequency] is [MedicineFrequency.once].
  final DateTime? onceDate;

  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional pill count for refill tracking. When the stock reaches
  /// [refillAt], a refill reminder notification is shown.
  final int? stockCount;
  final int? refillAt;

  /// Reminder times. Always populated after hydration from the database.
  final List<MedicineSchedule> schedules;

  const Medicine({
    this.id,
    required this.name,
    this.dosage = '',
    this.dosageUnit = '',
    this.notes = '',
    this.foodInstruction = FoodInstruction.none,
    this.frequency = MedicineFrequency.daily,
    this.selectedDays = const [],
    this.onceDate,
    this.active = true,
    this.stockCount,
    this.refillAt,
    required this.createdAt,
    required this.updatedAt,
    this.schedules = const [],
  });

  /// Whether stock tracking is enabled for this medicine.
  bool get hasStockTracking => stockCount != null;

  /// Whether the stock is at or below the refill threshold.
  bool get needsRefill =>
      stockCount != null && refillAt != null && stockCount! <= refillAt!;

  Medicine copyWithSchedules(List<MedicineSchedule> schedules) {
    return copyWith(schedules: schedules);
  }

  /// "1 tablet" style dose label for display and notifications.
  String get doseLabel {
    final parts = [
      dosage.trim(),
      dosageUnit.trim(),
    ].where((p) => p.isNotEmpty).toList();
    return parts.join(' ');
  }

  Medicine copyWith({
    int? id,
    String? name,
    String? dosage,
    String? dosageUnit,
    String? notes,
    FoodInstruction? foodInstruction,
    MedicineFrequency? frequency,
    List<int>? selectedDays,
    DateTime? onceDate,
    bool? active,
    int? stockCount,
    int? refillAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MedicineSchedule>? schedules,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      dosageUnit: dosageUnit ?? this.dosageUnit,
      notes: notes ?? this.notes,
      foodInstruction: foodInstruction ?? this.foodInstruction,
      frequency: frequency ?? this.frequency,
      selectedDays: selectedDays ?? this.selectedDays,
      onceDate: onceDate ?? this.onceDate,
      active: active ?? this.active,
      stockCount: stockCount ?? this.stockCount,
      refillAt: refillAt ?? this.refillAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schedules: schedules ?? this.schedules,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'dosage': dosage,
      'dosage_unit': dosageUnit,
      'notes': notes,
      'food_instruction': foodInstruction.name,
      'frequency': frequency.name,
      'selected_days': _encodeDays(selectedDays),
      'once_date': onceDate == null
          ? null
          : '${onceDate!.year.toString().padLeft(4, '0')}-'
                '${onceDate!.month.toString().padLeft(2, '0')}-'
                '${onceDate!.day.toString().padLeft(2, '0')}',
      'active': active ? 1 : 0,
      'stock_count': stockCount,
      'refill_at': refillAt,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static Medicine fromMap(Map<String, Object?> map) {
    final days = _decodeDays(map['selected_days'] as String?);
    final once = map['once_date'] as String?;
    return Medicine(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      dosage: (map['dosage'] as String?) ?? '',
      dosageUnit: (map['dosage_unit'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      foodInstruction: FoodInstruction.from(
        (map['food_instruction'] as String?) ?? 'none',
      ),
      frequency: MedicineFrequency.from(
        (map['frequency'] as String?) ?? 'daily',
      ),
      selectedDays: days,
      onceDate: once == null ? null : DateTime.tryParse(once),
      active: (map['active'] as int? ?? 1) == 1,
      stockCount: map['stock_count'] as int?,
      refillAt: map['refill_at'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  static String _encodeDays(List<int> days) =>
      days.map((d) => d.toString()).join(',');

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
