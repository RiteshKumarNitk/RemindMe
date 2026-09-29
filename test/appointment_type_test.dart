import 'package:medireminder/data/models/healthcare/appointment_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAppointmentTypes', () {
    test('parses a well-formed public payload', () {
      final types = parseAppointmentTypes([
        {'id': 't1', 'name': 'Consultation', 'durationMinutes': 15},
        {'id': 't2', 'name': 'Follow-up', 'durationMinutes': 30},
      ]);
      expect(types, hasLength(2));
      expect(types[0].id, 't1');
      expect(types[0].name, 'Consultation');
      expect(types[0].durationMinutes, 15);
    });

    test('returns empty for null/absent payload (clinics with none)', () {
      expect(parseAppointmentTypes(null), isEmpty);
      expect(parseAppointmentTypes(const []), isEmpty);
    });

    test('skips malformed rows instead of throwing', () {
      final types = parseAppointmentTypes([
        {'id': 'ok', 'name': 'Consultation', 'durationMinutes': 20},
        {'id': null, 'name': 'Broken', 'durationMinutes': 10},
        {'id': 'x', 'name': null, 'durationMinutes': 10},
        {'id': 'y', 'name': 'Bad duration', 'durationMinutes': '15'},
        'garbage',
      ]);
      expect(types, hasLength(1));
      expect(types.single.id, 'ok');
    });
  });
}
