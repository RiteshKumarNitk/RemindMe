class PrescriptionItem {
  const PrescriptionItem({
    required this.id,
    required this.drugName,
    this.strength,
    this.form,
    this.dosage,
    this.frequency,
    this.durationDays,
    required this.foodInstruction,
    this.instructions,
  });

  final String id;
  final String drugName;
  final String? strength;
  final String? form;
  final String? dosage;
  final String? frequency;
  final int? durationDays;
  final String foodInstruction;
  final String? instructions;

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      id: json['id'] as String,
      drugName: json['drugName'] as String,
      strength: json['strength'] as String?,
      form: json['form'] as String?,
      dosage: json['dosage'] as String?,
      frequency: json['frequency'] as String?,
      durationDays: json['durationDays'] as int?,
      foodInstruction: json['foodInstruction'] as String? ?? 'NONE',
      instructions: json['instructions'] as String?,
    );
  }
}

class Prescription {
  const Prescription({
    required this.id,
    required this.organizationId,
    this.consultationId,
    required this.patientId,
    required this.doctorId,
    required this.issuedAt,
    this.notes,
    required this.items,
    this.doctorName,
    this.patientFirstName,
    this.patientLastName,
  });

  final String id;
  final String organizationId;
  final String? consultationId;
  final String patientId;
  final String doctorId;
  final DateTime issuedAt;
  final String? notes;
  final List<PrescriptionItem> items;
  final String? doctorName;
  final String? patientFirstName;
  final String? patientLastName;

  factory Prescription.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>? ?? [];
    return Prescription(
      id: json['id'] as String,
      organizationId: json['organizationId'] as String,
      consultationId: json['consultationId'] as String?,
      patientId: json['patientId'] as String,
      doctorId: json['doctorId'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String).toLocal(),
      notes: json['notes'] as String?,
      items: itemsList.map((e) => PrescriptionItem.fromJson(e as Map<String, dynamic>)).toList(),
      doctorName: json['doctor']?['displayName'] as String?,
      patientFirstName: json['patient']?['firstName'] as String?,
      patientLastName: json['patient']?['lastName'] as String?,
    );
  }
}
