import 'json_utils.dart';

/// A publicly listed branch of a healthcare organization.
///
/// Only fields the public API exposes are parsed — no internal address
/// notes, no staff-only metadata.
class ClinicLocation {
  const ClinicLocation({
    required this.id,
    required this.name,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.phone,
  });

  final String id;
  final String name;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? phone;

  factory ClinicLocation.fromJson(Map<String, dynamic> json) {
    return ClinicLocation(
      id: asStringOr(json['id']),
      name: asStringOr(json['name'], 'Location'),
      addressLine1: asString(json['addressLine1']),
      addressLine2: asString(json['addressLine2']),
      city: asString(json['city']),
      state: asString(json['state']),
      postalCode: asString(json['postalCode']),
      country: asString(json['country']),
      phone: asString(json['phone']),
    );
  }

  /// Single-line address for compact display; empty when nothing is known.
  String get shortAddress =>
      [city, state].where((p) => p != null && p.isNotEmpty).join(', ');

  /// Full postal address, one part per line.
  String get fullAddress => [
    addressLine1,
    addressLine2,
    [city, state, postalCode].where((p) => p != null && p.isNotEmpty).join(', '),
    country,
  ].where((p) => p != null && p.trim().isNotEmpty).join('\n');
}
