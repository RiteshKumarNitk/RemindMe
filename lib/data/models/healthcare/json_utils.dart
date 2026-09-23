/// Small, defensive JSON helpers.
///
/// The app never invents healthcare data — everything shown comes from the
/// platform API. That also means every field can legitimately be absent
/// (a clinic with no tagline, a doctor with no published fee), so parsing
/// must never throw on a missing or null value; it degrades to null/empty
/// and the UI hides what it does not have.
library;

Map<String, dynamic>? asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry(k.toString(), v));
  return null;
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value.map(asMap).whereType<Map<String, dynamic>>().toList();
}

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList(growable: false);
}

String? asString(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is num || value is bool) return value.toString();
  return null;
}

String asStringOr(Object? value, [String fallback = '']) =>
    asString(value) ?? fallback;

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? asBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return null;
}

/// Parses an ISO-8601 instant into a UTC [DateTime].
DateTime? asUtcDateTime(Object? value) {
  final raw = asString(value);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  return parsed?.toUtc();
}

/// Parses a `YYYY-MM-DD` calendar date (no time component, no timezone).
DateTime? asCalendarDate(Object? value) {
  final raw = asString(value);
  if (raw == null) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// `true` only when the backend explicitly marked the row removed/inactive.
bool asActive(Object? value) => asBool(value) ?? true;
