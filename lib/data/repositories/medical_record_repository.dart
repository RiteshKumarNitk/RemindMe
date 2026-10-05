import '../api/api_client.dart';
import '../models/healthcare/appointment.dart';
import '../models/healthcare/consultation.dart';
import '../models/healthcare/prescription.dart';
import 'appointment_repository.dart';

class MedicalRecordRepository {
  MedicalRecordRepository({
    required ApiClient client,
    required AppointmentRepository appointments,
  }) : _client = client,
       _appointments = appointments;

  final ApiClient _client;
  final AppointmentRepository _appointments;

  Future<List<Consultation>> myConsultations() async {
    final organizations = await _appointments.myOrganizations();
    final patientOrgs = organizations
        .where((org) => org.isPatientRole && org.isActive)
        .toList(growable: false);
    if (patientOrgs.isEmpty) return const [];

    final results = await Future.wait(
      patientOrgs.map((org) => _consultationsForOrg(org)),
    );

    final flattened = results.expand((rows) => rows).toList()
      ..sort((a, b) => (b.signedAt ?? DateTime.now()).compareTo(a.signedAt ?? DateTime.now()));
    return flattened;
  }

  Future<List<Consultation>> _consultationsForOrg(MyOrganization org) async {
    final json = await _client.getList(
      '/orgs/${Uri.encodeComponent(org.id)}/consultations',
      auth: AuthMode.required,
      query: {'limit': '100'},
    );
    return json.map((item) => Consultation.fromJson(item as Map<String, dynamic>)).toList(growable: false);
  }

  Future<List<Prescription>> myPrescriptions() async {
    final organizations = await _appointments.myOrganizations();
    final patientOrgs = organizations
        .where((org) => org.isPatientRole && org.isActive)
        .toList(growable: false);
    if (patientOrgs.isEmpty) return const [];

    final results = await Future.wait(
      patientOrgs.map((org) => _prescriptionsForOrg(org)),
    );

    final flattened = results.expand((rows) => rows).toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    return flattened;
  }

  Future<List<Prescription>> _prescriptionsForOrg(MyOrganization org) async {
    final json = await _client.getList(
      '/orgs/${Uri.encodeComponent(org.id)}/prescriptions',
      auth: AuthMode.required,
      query: {'limit': '100'},
    );
    return json.map((item) => Prescription.fromJson(item as Map<String, dynamic>)).toList(growable: false);
  }
}
