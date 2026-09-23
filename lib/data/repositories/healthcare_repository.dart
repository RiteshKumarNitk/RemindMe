import '../api/api_client.dart';
import '../models/healthcare/availability.dart';
import '../models/healthcare/doctor.dart';
import '../models/healthcare/organization.dart';
import '../models/healthcare/page.dart';

/// Public healthcare discovery.
///
/// Everything here reads the **unauthenticated** `/api/public/...` endpoints,
/// which the platform already restricts to organizations and doctors that
/// are active and publicly listed. The app never adds its own visibility
/// rules — if the API returns it, it is publishable; if it doesn't, the
/// screen shows an empty state.
class HealthcareRepository {
  HealthcareRepository({required ApiClient client}) : _client = client;

  final ApiClient _client;

  /// Detail payloads are cached briefly so tapping back-and-forth between a
  /// clinic and its doctors doesn't re-hit the network. Keyed by slug/id.
  final Map<String, _CacheEntry<OrganizationDetail>> _organizationCache = {};
  final Map<String, _CacheEntry<DoctorDetail>> _doctorCache = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  /// Organizations eligible for public discovery.
  Future<Page<OrganizationSummary>> searchOrganizations({
    String? query,
    String? city,
    String? orgType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _client.getObject(
      '/public/organizations',
      auth: AuthMode.none,
      query: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        if (orgType != null && orgType.isNotEmpty) 'orgType': orgType,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    return Page.fromJson(json, OrganizationSummary.fromJson);
  }

  /// Public profile of one organization.
  Future<OrganizationDetail> organizationBySlug(
    String slug, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _organizationCache[slug]?.fresh(_cacheTtl);
      if (cached != null) return cached;
    }
    final json = await _client.getObject(
      '/public/organizations/${Uri.encodeComponent(slug)}',
      auth: AuthMode.none,
    );
    final detail = OrganizationDetail.fromJson(json);
    _organizationCache[slug] = _CacheEntry(detail);
    return detail;
  }

  /// Doctors across every publicly listed organization.
  Future<Page<DoctorSummary>> searchDoctors({
    String? query,
    String? specialty,
    String? organizationSlug,
    int page = 1,
    int pageSize = 20,
  }) async {
    final json = await _client.getObject(
      '/public/doctors',
      auth: AuthMode.none,
      query: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (specialty != null && specialty.trim().isNotEmpty)
          'specialty': specialty.trim(),
        if (organizationSlug != null && organizationSlug.isNotEmpty)
          'organizationSlug': organizationSlug,
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    return Page.fromJson(json, DoctorSummary.fromJson);
  }

  /// Public profile of one doctor.
  Future<DoctorDetail> doctorById(
    String doctorId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _doctorCache[doctorId]?.fresh(_cacheTtl);
      if (cached != null) return cached;
    }
    final json = await _client.getObject(
      '/public/doctors/${Uri.encodeComponent(doctorId)}',
      auth: AuthMode.none,
    );
    final detail = DoctorDetail.fromJson(json);
    _doctorCache[doctorId] = _CacheEntry(detail);
    return detail;
  }

  /// The doctor's genuinely open slots for [date] (a calendar day in the
  /// clinic's timezone). Slots already booked, outside the clinic's booking
  /// lead time, or outside published availability are filtered by the
  /// backend — the app displays what it is given and computes nothing.
  Future<DoctorAvailability> doctorAvailability(
    String doctorId, {
    required DateTime date,
    String? appointmentTypeId,
  }) async {
    final json = await _client.getObject(
      '/public/doctors/${Uri.encodeComponent(doctorId)}/slots',
      auth: AuthMode.none,
      query: {
        'date': formatDateParam(date),
        if (appointmentTypeId != null) 'appointmentTypeId': appointmentTypeId,
      },
    );
    return DoctorAvailability.fromJson(json);
  }

  void clearCaches() {
    _organizationCache.clear();
    _doctorCache.clear();
  }
}

/// `YYYY-MM-DD`, timezone-free — the shape the slots endpoint expects.
String formatDateParam(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

class _CacheEntry<T> {
  _CacheEntry(this.value) : storedAt = DateTime.now();

  final T value;
  final DateTime storedAt;

  T? fresh(Duration ttl) =>
      DateTime.now().difference(storedAt) < ttl ? value : null;
}
