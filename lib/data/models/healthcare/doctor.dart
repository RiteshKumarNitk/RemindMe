import 'clinic_location.dart';
import 'json_utils.dart';

/// A publicly listed doctor, as the discovery list endpoint returns it.
class DoctorSummary {
  const DoctorSummary({
    required this.id,
    required this.displayName,
    this.specialty,
    this.photoUrl,
    this.yearsOfExperience,
    this.languages = const [],
    this.consultationFeeMinor,
    this.organizationId,
    this.organizationName,
    this.organizationSlug,
    this.organizationLogoUrl,
  });

  final String id;
  final String displayName;
  final String? specialty;
  final String? photoUrl;
  final int? yearsOfExperience;
  final List<String> languages;

  /// Consultation fee in currency minor units (paise). Null when the clinic
  /// has not published one — the UI then shows no fee at all rather than a
  /// made-up number.
  final int? consultationFeeMinor;

  final String? organizationId;
  final String? organizationName;
  final String? organizationSlug;
  final String? organizationLogoUrl;

  factory DoctorSummary.fromJson(Map<String, dynamic> json) {
    final org = asMap(json['organization']);
    return DoctorSummary(
      id: asStringOr(json['id']),
      displayName: asStringOr(json['displayName'], 'Doctor'),
      specialty: asString(json['specialty']),
      photoUrl: asString(json['photoUrl']),
      yearsOfExperience: asInt(json['yearsOfExperience']),
      languages: asStringList(json['languages']),
      consultationFeeMinor: asInt(json['consultationFeeMinor']),
      organizationId: org == null ? null : asString(org['id']),
      organizationName: org == null ? null : asString(org['name']),
      organizationSlug: org == null ? null : asString(org['slug']),
      organizationLogoUrl: org == null ? null : asString(org['logoUrl']),
    );
  }
}

/// The clinic a doctor belongs to, as embedded in the doctor detail payload.
class DoctorOrganization {
  const DoctorOrganization({
    required this.id,
    required this.name,
    this.slug,
    this.logoUrl,
    this.publicPhone,
    this.publicEmail,
    this.locations = const [],
  });

  final String id;
  final String name;
  final String? slug;
  final String? logoUrl;
  final String? publicPhone;
  final String? publicEmail;
  final List<ClinicLocation> locations;

  factory DoctorOrganization.fromJson(Map<String, dynamic> json) {
    return DoctorOrganization(
      id: asStringOr(json['id']),
      name: asStringOr(json['name'], 'Clinic'),
      slug: asString(json['slug']),
      logoUrl: asString(json['logoUrl']),
      publicPhone: asString(json['publicPhone']),
      publicEmail: asString(json['publicEmail']),
      locations: asMapList(json['locations'])
          .map(ClinicLocation.fromJson)
          .toList(growable: false),
    );
  }
}

/// The full public doctor profile.
class DoctorDetail {
  const DoctorDetail({
    required this.id,
    required this.displayName,
    this.specialty,
    this.bio,
    this.qualifications,
    this.registrationNumber,
    this.photoUrl,
    this.yearsOfExperience,
    this.languages = const [],
    this.consultationFeeMinor,
    required this.organization,
  });

  final String id;
  final String displayName;
  final String? specialty;
  final String? bio;
  final String? qualifications;
  final String? registrationNumber;
  final String? photoUrl;
  final int? yearsOfExperience;
  final List<String> languages;
  final int? consultationFeeMinor;
  final DoctorOrganization organization;

  factory DoctorDetail.fromJson(Map<String, dynamic> json) {
    return DoctorDetail(
      id: asStringOr(json['id']),
      displayName: asStringOr(json['displayName'], 'Doctor'),
      specialty: asString(json['specialty']),
      bio: asString(json['bio']),
      qualifications: asString(json['qualifications']),
      registrationNumber: asString(json['registrationNumber']),
      photoUrl: asString(json['photoUrl']),
      yearsOfExperience: asInt(json['yearsOfExperience']),
      languages: asStringList(json['languages']),
      consultationFeeMinor: asInt(json['consultationFeeMinor']),
      organization: DoctorOrganization.fromJson(
        asMap(json['organization']) ?? const {},
      ),
    );
  }

  DoctorSummary toSummary() => DoctorSummary(
    id: id,
    displayName: displayName,
    specialty: specialty,
    photoUrl: photoUrl,
    yearsOfExperience: yearsOfExperience,
    languages: languages,
    consultationFeeMinor: consultationFeeMinor,
    organizationId: organization.id,
    organizationName: organization.name,
    organizationSlug: organization.slug,
    organizationLogoUrl: organization.logoUrl,
  );
}
