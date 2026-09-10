import 'dose_status.dart';

/// A single scheduled occurrence of a medicine dose.
class MedicineDose {
  final int? id;
  final int medicineId;
  final DateTime scheduledAt;
  final DoseStatus status;
  final DateTime? takenAt;
  final DateTime? skippedAt;

  /// When a snooze was requested for this dose (notification fires again
  /// at this time).
  final DateTime? snoozedUntil;
  final DateTime createdAt;

  /// Used for cloud-sync conflict resolution (last writer wins).
  final DateTime updatedAt;

  MedicineDose({
    this.id,
    required this.medicineId,
    required this.scheduledAt,
    this.status = DoseStatus.pending,
    this.takenAt,
    this.skippedAt,
    this.snoozedUntil,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Sentinel value to distinguish "parameter not supplied" from
  /// "parameter explicitly supplied as null" in [copyWith].
  static const _sentinel = Object();

  MedicineDose copyWith({
    int? id,
    int? medicineId,
    DateTime? scheduledAt,
    DoseStatus? status,
    Object? takenAt = _sentinel,
    Object? skippedAt = _sentinel,
    Object? snoozedUntil = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicineDose(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      status: status ?? this.status,
      takenAt: identical(takenAt, _sentinel) ? this.takenAt : takenAt as DateTime?,
      skippedAt: identical(skippedAt, _sentinel) ? this.skippedAt : skippedAt as DateTime?,
      snoozedUntil: identical(snoozedUntil, _sentinel) ? this.snoozedUntil : snoozedUntil as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'medicine_id': medicineId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'status': status.name,
      'taken_at': takenAt?.toIso8601String(),
      'skipped_at': skippedAt?.toIso8601String(),
      'snoozed_until': snoozedUntil?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static MedicineDose fromMap(Map<String, Object?> map) {
    return MedicineDose(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      scheduledAt: DateTime.parse(map['scheduled_at'] as String),
      status: DoseStatus.from((map['status'] as String?) ?? 'pending'),
      takenAt: map['taken_at'] == null
          ? null
          : DateTime.parse(map['taken_at'] as String),
      skippedAt: map['skipped_at'] == null
          ? null
          : DateTime.parse(map['skipped_at'] as String),
      snoozedUntil: map['snoozed_until'] == null
          ? null
          : DateTime.parse(map['snoozed_until'] as String),
      createdAt: map['created_at'] == null
          ? DateTime.now()
          : DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] == null
          ? DateTime.now()
          : DateTime.parse(map['updated_at'] as String),
    );
  }
}
