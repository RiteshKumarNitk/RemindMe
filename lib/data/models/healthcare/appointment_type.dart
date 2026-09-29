/// An appointment type as published on the clinic's public profile
/// (additive backend payload: `appointmentTypes` on org detail / doctor
/// detail). Only the fields the public API returns — no fee, no colour.
class AppointmentTypeInfo {
  const AppointmentTypeInfo({
    required this.id,
    required this.name,
    required this.durationMinutes,
  });

  final String id;
  final String name;
  final int durationMinutes;

  static AppointmentTypeInfo? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final name = json['name'] as String?;
    final duration = json['durationMinutes'];
    if (id == null || name == null || duration is! int) return null;
    return AppointmentTypeInfo(id: id, name: name, durationMinutes: duration);
  }
}

/// Parses the `appointmentTypes` array from a public org/doctor payload,
/// tolerating absence (clinics that configured none) and malformed rows.
List<AppointmentTypeInfo> parseAppointmentTypes(dynamic raw) {
  if (raw is! List) return const [];
  final out = <AppointmentTypeInfo>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final parsed = AppointmentTypeInfo.fromJson(
      item.map((key, value) => MapEntry('$key', value)),
    );
    if (parsed != null) out.add(parsed);
  }
  return out;
}
