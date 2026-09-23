import 'json_utils.dart';

/// Appointment states, exactly as the backend defines them.
enum AppointmentStatus {
  requested('REQUESTED'),
  confirmed('CONFIRMED'),
  checkedIn('CHECKED_IN'),
  waiting('WAITING'),
  inConsultation('IN_CONSULTATION'),
  completed('COMPLETED'),
  cancelled('CANCELLED'),
  noShow('NO_SHOW'),
  rescheduled('RESCHEDULED'),
  unknown('UNKNOWN');

  const AppointmentStatus(this.apiValue);

  final String apiValue;

  static AppointmentStatus fromApi(Object? value) {
    final raw = asString(value)?.toUpperCase();
    if (raw == null) return AppointmentStatus.unknown;
    for (final status in AppointmentStatus.values) {
      if (status.apiValue == raw) return status;
    }
    return AppointmentStatus.unknown;
  }

  /// Still going to happen (or happening) — belongs in "Upcoming".
  bool get isUpcoming =>
      this == confirmed ||
      this == requested ||
      this == checkedIn ||
      this == waiting ||
      this == inConsultation;

  bool get isCancelled => this == cancelled;

  /// Finished one way or another — belongs in "Past"/"Cancelled".
  bool get isClosed =>
      this == completed ||
      this == cancelled ||
      this == noShow ||
      this == rescheduled;

  /// Whether the patient may still cancel it (mirrors the backend's legal
  /// transitions; the server stays authoritative and re-checks).
  bool get canCancel =>
      this == requested || this == confirmed || this == checkedIn;

  /// Whether the patient may reschedule it.
  bool get canReschedule => this == requested || this == confirmed;
}

/// A queue ticket tied to a checked-in appointment.
///
/// Patients can read their own ticket (token + state + position). The
/// clinic's "now serving" counter is staff-only today — see the audit notes.
class QueueEntry {
  const QueueEntry({
    required this.id,
    required this.tokenNumber,
    required this.state,
    this.position,
    this.calledAt,
  });

  final String id;
  final int tokenNumber;
  final String state;
  final int? position;
  final DateTime? calledAt;

  static QueueEntry? fromJson(Object? raw) {
    final json = asMap(raw);
    if (json == null) return null;
    final id = asString(json['id']);
    final token = asInt(json['tokenNumber']);
    if (id == null || token == null) return null;
    return QueueEntry(
      id: id,
      tokenNumber: token,
      state: asStringOr(json['state'], 'WAITING'),
      position: asInt(json['position']),
      calledAt: asUtcDateTime(json['calledAt']),
    );
  }

  bool get isWaiting => state == 'WAITING';
  bool get isCalled => state == 'CALLED';
  bool get isInConsultation => state == 'IN_CONSULTATION';
  bool get isDone => state == 'COMPLETED' || state == 'SKIPPED';
}

/// An appointment as the platform stores it.
class Appointment {
  const Appointment({
    required this.id,
    required this.organizationId,
    this.patientId,
    this.doctorId,
    this.locationId,
    this.appointmentTypeId,
    required this.scheduledStart,
    this.scheduledEnd,
    this.timezone = 'UTC',
    required this.status,
    this.reason,
    this.notes,
    this.cancelledAt,
    this.cancellationReason,
    this.rescheduledFromId,
    this.doctorName,
    this.patientName,
    this.queueEntry,
  });

  final String id;
  final String organizationId;
  final String? patientId;
  final String? doctorId;
  final String? locationId;
  final String? appointmentTypeId;

  /// UTC instant of the appointment.
  final DateTime scheduledStart;
  final DateTime? scheduledEnd;

  /// IANA zone the clinic booked it in.
  final String timezone;

  final AppointmentStatus status;
  final String? reason;
  final String? notes;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? rescheduledFromId;
  final String? doctorName;
  final String? patientName;
  final QueueEntry? queueEntry;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final doctor = asMap(json['doctor']);
    final patient = asMap(json['patient']);
    return Appointment(
      id: asStringOr(json['id']),
      organizationId: asStringOr(json['organizationId']),
      patientId: asString(json['patientId']),
      doctorId: asString(json['doctorId']),
      locationId: asString(json['locationId']),
      appointmentTypeId: asString(json['appointmentTypeId']),
      scheduledStart:
          asUtcDateTime(json['scheduledStart']) ?? DateTime.now().toUtc(),
      scheduledEnd: asUtcDateTime(json['scheduledEnd']),
      timezone: asStringOr(json['timezone'], 'UTC'),
      status: AppointmentStatus.fromApi(json['status']),
      reason: asString(json['reason']),
      notes: asString(json['notes']),
      cancelledAt: asUtcDateTime(json['cancelledAt']),
      cancellationReason: asString(json['cancellationReason']),
      rescheduledFromId: asString(json['rescheduledFromId']),
      doctorName: doctor == null ? null : asString(doctor['displayName']),
      patientName: patient == null
          ? null
          : [
              asString(patient['firstName']),
              asString(patient['lastName']),
            ].whereType<String>().join(' '),
      queueEntry: QueueEntry.fromJson(json['queueEntry']),
    );
  }
}

/// An organization the signed-in patient is linked to, from `GET /api/orgs`.
///
/// This is how the app discovers *which* clinics to ask for appointments —
/// the backend decides membership, never the app.
class MyOrganization {
  const MyOrganization({
    required this.id,
    required this.name,
    this.slug,
    this.timezone = 'UTC',
    this.role = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String? slug;
  final String timezone;
  final String role;
  final bool isActive;

  factory MyOrganization.fromJson(Map<String, dynamic> json) {
    return MyOrganization(
      id: asStringOr(json['id']),
      name: asStringOr(json['name'], 'Clinic'),
      slug: asString(json['slug']),
      timezone: asStringOr(json['timezone'], 'UTC'),
      role: asStringOr(json['role']),
      isActive: asActive(json['isActive']),
    );
  }

  bool get isPatientRole => role.toUpperCase() == 'PATIENT';
}

/// The signed-in platform user (`GET /api/me`).
class PlatformUser {
  const PlatformUser({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.locale,
    this.isGuest = false,
  });

  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? locale;

  /// Guest accounts are refused by the booking API, so the app must not let
  /// one start a booking.
  final bool isGuest;

  factory PlatformUser.fromJson(Map<String, dynamic> json) {
    return PlatformUser(
      id: asStringOr(json['id']),
      email: asStringOr(json['email']),
      fullName: asString(json['fullName']),
      phone: asString(json['phone']),
      avatarUrl: asString(json['avatarUrl']),
      locale: asString(json['locale']),
      isGuest: asBool(json['isGuest']) ?? false,
    );
  }

  String get firstName {
    final parts = _nameParts;
    return parts.isEmpty ? '' : parts.first;
  }

  String get lastName {
    final parts = _nameParts;
    return parts.length <= 1 ? '' : parts.sublist(1).join(' ');
  }

  List<String> get _nameParts =>
      (fullName ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
}
