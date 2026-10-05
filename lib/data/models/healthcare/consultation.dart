class Consultation {
  const Consultation({
    required this.id,
    required this.organizationId,
    required this.appointmentId,
    required this.patientId,
    required this.doctorId,
    this.subjective,
    this.objective,
    this.assessment,
    this.plan,
    this.followUpDate,
    this.testsAdvised,
    this.instructions,
    this.signedAt,
    this.doctorName,
    this.patientFirstName,
    this.patientLastName,
  });

  final String id;
  final String organizationId;
  final String appointmentId;
  final String patientId;
  final String doctorId;
  final String? subjective;
  final String? objective;
  final String? assessment;
  final String? plan;
  final DateTime? followUpDate;
  final String? testsAdvised;
  final String? instructions;
  final DateTime? signedAt;
  final String? doctorName;
  final String? patientFirstName;
  final String? patientLastName;

  factory Consultation.fromJson(Map<String, dynamic> json) {
    return Consultation(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      appointmentId: json['appointmentId'] as String,
      patientId: json['patientId'] as String,
      doctorId: json['doctorId'] as String,
      subjective: json['subjective'] as String?,
      objective: json['objective'] as String?,
      assessment: json['assessment'] as String?,
      plan: json['plan'] as String?,
      followUpDate: json['followUpDate'] != null ? DateTime.parse(json['followUpDate'] as String) : null,
      testsAdvised: json['testsAdvised'] as String?,
      instructions: json['instructions'] as String?,
      signedAt: json['signedAt'] != null ? DateTime.parse(json['signedAt'] as String).toLocal() : null,
      doctorName: json['doctor']?['displayName'] as String?,
      patientFirstName: json['patient']?['firstName'] as String?,
      patientLastName: json['patient']?['lastName'] as String?,
    );
  }
}
