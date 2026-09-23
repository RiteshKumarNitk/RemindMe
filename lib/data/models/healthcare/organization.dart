import 'clinic_location.dart';
import 'doctor.dart';
import 'json_utils.dart';

/// Organization types the platform defines. Kept as a string straight from
/// the API (never invented client-side); only the display label is local.
class OrganizationType {
  static const String hospital = 'HOSPITAL';
  static const String clinic = 'CLINIC';
  static const String polyclinic = 'POLYCLINIC';
  static const String diagnosticCenter = 'DIAGNOSTIC_CENTER';
  static const String other = 'OTHER';
}

/// One entry in the public clinic/hospital list.
class OrganizationSummary {
  const OrganizationSummary({
    required this.id,
    required this.slug,
    required this.name,
    this.tagline,
    this.logoUrl,
    this.orgType,
    this.verificationStatus,
    this.cities = const [],
    this.doctorCount = 0,
  });

  final String id;
  final String slug;
  final String name;
  final String? tagline;
  final String? logoUrl;

  /// `HOSPITAL`, `CLINIC`, … or null when the clinic hasn't set one.
  final String? orgType;

  /// `VERIFIED` / `PENDING` / … — the raw backend value.
  final String? verificationStatus;

  final List<String> cities;

  /// How many publicly listed, active doctors the clinic has.
  final int doctorCount;

  factory OrganizationSummary.fromJson(Map<String, dynamic> json) {
    final counts = asMap(json['_count']);
    final locations = asMapList(json['locations']);
    final cities = <String>[];
    for (final location in locations) {
      final city = asString(location['city']);
      if (city != null && !cities.contains(city)) cities.add(city);
    }
    return OrganizationSummary(
      id: asStringOr(json['id']),
      slug: asStringOr(json['slug']),
      name: asStringOr(json['name'], 'Healthcare provider'),
      tagline: asString(json['tagline']),
      logoUrl: asString(json['logoUrl']),
      orgType: asString(json['orgType']),
      verificationStatus: asString(json['verificationStatus']),
      cities: cities,
      doctorCount: counts == null
          ? 0
          : (asInt(counts['doctorProfiles']) ?? 0),
    );
  }

  /// True only when the platform itself marked this organization verified.
  bool get isVerified => verificationStatus?.toUpperCase() == 'VERIFIED';
}

/// The full public profile of an organization.
class OrganizationDetail {
  const OrganizationDetail({
    required this.id,
    required this.slug,
    required this.name,
    this.tagline,
    this.about,
    this.logoUrl,
    this.coverImageUrl,
    this.orgType,
    this.publicPhone,
    this.publicEmail,
    this.website,
    this.verificationStatus,
    this.locations = const [],
    this.doctors = const [],
  });

  final String id;
  final String slug;
  final String name;
  final String? tagline;
  final String? about;
  final String? logoUrl;
  final String? coverImageUrl;
  final String? orgType;
  final String? publicPhone;
  final String? publicEmail;
  final String? website;
  final String? verificationStatus;
  final List<ClinicLocation> locations;
  final List<DoctorSummary> doctors;

  factory OrganizationDetail.fromJson(Map<String, dynamic> json) {
    return OrganizationDetail(
      id: asStringOr(json['id']),
      slug: asStringOr(json['slug']),
      name: asStringOr(json['name'], 'Healthcare provider'),
      tagline: asString(json['tagline']),
      about: asString(json['about']),
      logoUrl: asString(json['logoUrl']),
      coverImageUrl: asString(json['coverImageUrl']),
      orgType: asString(json['orgType']),
      publicPhone: asString(json['publicPhone']),
      publicEmail: asString(json['publicEmail']),
      website: asString(json['website']),
      verificationStatus: asString(json['verificationStatus']),
      locations: asMapList(json['locations'])
          .map(ClinicLocation.fromJson)
          .toList(growable: false),
      doctors: asMapList(json['doctorProfiles'])
          .map(DoctorSummary.fromJson)
          .toList(growable: false),
    );
  }

  bool get isVerified => verificationStatus?.toUpperCase() == 'VERIFIED';
}
