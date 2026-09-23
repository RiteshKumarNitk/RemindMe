import 'json_utils.dart';

/// One bookable time. [start]/[end] are UTC instants; render them in
/// [DoctorAvailability.timezone] (the clinic's own zone), exactly as the
/// backend computed them — never re-derive availability locally.
class AvailabilitySlot {
  const AvailabilitySlot({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  /// The instant the API expects back in `scheduledStart` — the raw ISO
  /// string, so no local timezone conversion can shift it.
  String get startIso => start.toIso8601String();

  static AvailabilitySlot? fromJson(Map<String, dynamic> json) {
    final start = asUtcDateTime(json['start']);
    final end = asUtcDateTime(json['end']);
    if (start == null || end == null) return null;
    return AvailabilitySlot(start: start, end: end);
  }
}

/// The result of asking the backend for a doctor's open slots on one day.
class DoctorAvailability {
  const DoctorAvailability({
    required this.slots,
    required this.timezone,
    required this.durationMinutes,
  });

  final List<AvailabilitySlot> slots;

  /// IANA zone of the clinic/location the slots belong to.
  final String timezone;

  /// Length of the appointment these slots were computed for.
  final int durationMinutes;

  static const DoctorAvailability empty = DoctorAvailability(
    slots: [],
    timezone: 'UTC',
    durationMinutes: 0,
  );

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) {
    final slots = asMapList(json['slots'])
        .map(AvailabilitySlot.fromJson)
        .whereType<AvailabilitySlot>()
        .toList(growable: false);
    return DoctorAvailability(
      slots: slots,
      timezone: asStringOr(json['timezone'], 'UTC'),
      durationMinutes: asInt(json['durationMinutes']) ?? 0,
    );
  }
}
