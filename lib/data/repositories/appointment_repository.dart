import '../api/api_client.dart';
import '../models/healthcare/appointment.dart';
import '../models/healthcare/clinic_location.dart';
import 'healthcare_repository.dart';

/// The demographic block the booking API requires the first time a patient
/// books with a clinic (the backend stores it as that clinic's Patient row).
class PatientDetails {
  const PatientDetails({
    required this.firstName,
    required this.lastName,
    this.phone,
    this.dateOfBirth,
    this.sex,
  });

  final String firstName;
  final String lastName;
  final String? phone;
  final DateTime? dateOfBirth;
  final String? sex;

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    if (phone != null && phone!.trim().isNotEmpty) 'phone': phone!.trim(),
    if (dateOfBirth != null)
      'dateOfBirth':
          '${dateOfBirth!.year.toString().padLeft(4, '0')}-'
          '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
          '${dateOfBirth!.day.toString().padLeft(2, '0')}',
    if (sex != null && sex!.isNotEmpty) 'sex': sex,
  };
}

/// An appointment together with the clinic it belongs to, and — when the
/// clinic's public profile is available — the branch it was booked at.
class PatientAppointment {
  const PatientAppointment({
    required this.appointment,
    required this.organization,
    this.location,
  });

  final Appointment appointment;
  final MyOrganization organization;
  final ClinicLocation? location;

  PatientAppointment withLocation(ClinicLocation? value) =>
      PatientAppointment(
        appointment: appointment,
        organization: organization,
        location: value,
      );
}

/// Everything a patient does with a real appointment on the platform.
///
/// Appointments are tenant-scoped on the backend, so the app first asks
/// which organizations this patient belongs to (`GET /api/orgs`) and then
/// reads that clinic's appointments — the server decides ownership, and a
/// patient only ever receives their own rows (plus dependents they manage).
class AppointmentRepository {
  AppointmentRepository({
    required ApiClient client,
    required HealthcareRepository healthcare,
  }) : _client = client,
       _healthcare = healthcare;

  final ApiClient _client;
  final HealthcareRepository _healthcare;

  /// Clinics this account is linked to (any role — the caller filters).
  Future<List<MyOrganization>> myOrganizations() async {
    final list = await _client.getList('/orgs', auth: AuthMode.required);
    return list.map(MyOrganization.fromJson).toList(growable: false);
  }

  /// Every appointment this patient can see, newest booking first per clinic,
  /// merged across clinics and sorted by time.
  ///
  /// [includeClosed] false asks each clinic for future appointments only
  /// (cheaper, and enough for the home card); true fetches the history the
  /// Past/Cancelled tabs need.
  Future<List<PatientAppointment>> myAppointments({
    bool includeClosed = true,
    DateTime? now,
  }) async {
    final organizations = await myOrganizations();
    final patientOrgs = organizations
        .where((org) => org.isPatientRole && org.isActive)
        .toList(growable: false);
    if (patientOrgs.isEmpty) return const [];

    final results = await Future.wait(
      patientOrgs.map((org) => _appointmentsForOrg(org, includeClosed: includeClosed, now: now)),
    );

    final flattened = results.expand((rows) => rows).toList()
      ..sort(
        (a, b) => b.appointment.scheduledStart.compareTo(
          a.appointment.scheduledStart,
        ),
      );
    return flattened;
  }

  Future<List<PatientAppointment>> _appointmentsForOrg(
    MyOrganization org, {
    required bool includeClosed,
    DateTime? now,
  }) async {
    final reference = (now ?? DateTime.now()).toUtc();
    final json = await _client.getList(
      '/orgs/${Uri.encodeComponent(org.id)}/appointments',
      auth: AuthMode.required,
      query: {
        'limit': includeClosed ? '100' : '25',
        if (!includeClosed) 'from': reference.toIso8601String(),
      },
    );

    final locations = await _locationsForOrg(org);
    return json
        .map(Appointment.fromJson)
        .map(
          (appointment) => PatientAppointment(
            appointment: appointment,
            organization: org,
            location: appointment.locationId == null
                ? null
                : locations[appointment.locationId!],
          ),
        )
        .toList(growable: false);
  }

  /// Branch id → branch, read from the clinic's *public* profile. A clinic
  /// that has since been unpublished simply yields no location labels.
  Future<Map<String, ClinicLocation>> _locationsForOrg(
    MyOrganization org,
  ) async {
    final slug = org.slug;
    if (slug == null || slug.isEmpty) return const {};
    try {
      final detail = await _healthcare.organizationBySlug(slug);
      return {for (final location in detail.locations) location.id: location};
    } catch (_) {
      return const {};
    }
  }

  /// Full detail of one appointment, including its queue ticket when the
  /// patient has been checked in.
  Future<Appointment> appointment({
    required String organizationId,
    required String appointmentId,
  }) async {
    final json = await _client.getObject(
      '/orgs/${Uri.encodeComponent(organizationId)}'
      '/appointments/${Uri.encodeComponent(appointmentId)}',
      auth: AuthMode.required,
    );
    return Appointment.fromJson(json);
  }

  /// Books a real appointment through the platform's own booking service.
  ///
  /// [scheduledStart] must be one of the instants the availability endpoint
  /// returned; the server re-validates lead time, availability and
  /// double-booking inside a serializable transaction. `organizationId` and
  /// `doctorId` come from the discovery flow, so the doctor is always booked
  /// in the context of the clinic the patient found them in.
  Future<Appointment> book({
    required String organizationId,
    required String doctorId,
    required DateTime scheduledStart,
    required PatientDetails patient,
    String? locationId,
    String? reason,
  }) async {
    final json = await _client.post(
      '/patient/appointments',
      auth: AuthMode.required,
      body: {
        'organizationId': organizationId,
        'doctorId': doctorId,
        'scheduledStart': scheduledStart.toUtc().toIso8601String(),
        if (locationId != null && locationId.isNotEmpty) 'locationId': locationId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        'patient': patient.toJson(),
      },
    );
    return Appointment.fromJson(json);
  }

  /// Cancels through the backend's lifecycle transition (which enforces the
  /// clinic's cancellation window and drops any queue ticket).
  Future<Appointment> cancel({
    required String organizationId,
    required String appointmentId,
    required String reason,
  }) async {
    final json = await _client.post(
      '/orgs/${Uri.encodeComponent(organizationId)}'
      '/appointments/${Uri.encodeComponent(appointmentId)}/cancel',
      auth: AuthMode.required,
      body: {'reason': reason.trim().isEmpty ? 'Cancelled by patient' : reason.trim()},
    );
    return Appointment.fromJson(json);
  }

  /// Reschedules to a new slot returned by the availability endpoint. The
  /// backend creates the replacement appointment and marks the old one
  /// RESCHEDULED, so the returned appointment is the one to show.
  Future<Appointment> reschedule({
    required String organizationId,
    required String appointmentId,
    required DateTime scheduledStart,
    String? reason,
  }) async {
    final json = await _client.post(
      '/orgs/${Uri.encodeComponent(organizationId)}'
      '/appointments/${Uri.encodeComponent(appointmentId)}/reschedule',
      auth: AuthMode.required,
      body: {
        'scheduledStart': scheduledStart.toUtc().toIso8601String(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final created = json['appointment'];
    if (created is Map<String, dynamic>) return Appointment.fromJson(created);
    if (created is Map) {
      return Appointment.fromJson(created.map((k, v) => MapEntry('$k', v)));
    }
    return Appointment.fromJson(json);
  }
}
