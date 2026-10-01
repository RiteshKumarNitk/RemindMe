import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/data/api/api_exception.dart';
import 'package:medireminder/data/models/healthcare/appointment.dart';
import 'package:medireminder/data/models/healthcare/doctor.dart';
import 'package:medireminder/data/models/healthcare/token.dart';
import 'package:medireminder/data/repositories/appointment_repository.dart';

import 'healthcare_test_helpers.dart';

/// Same-day token booking — the app is a thin client over the same backend
/// endpoints the website uses. These tests pin the request shapes and make
/// sure the app never computes window state, dates or ETAs itself.
void main() {
  group('BookingMode', () {
    test('parses every backend value and defaults to SCHEDULED', () {
      expect(BookingMode.fromApi('SAME_DAY_TOKEN'), BookingMode.sameDayToken);
      expect(BookingMode.fromApi('BOTH'), BookingMode.both);
      expect(BookingMode.fromApi('SCHEDULED'), BookingMode.scheduled);
      expect(BookingMode.fromApi(null), BookingMode.scheduled);
      expect(BookingMode.both.offersTokens, isTrue);
      expect(BookingMode.both.offersSlots, isTrue);
      expect(BookingMode.sameDayToken.offersSlots, isFalse);
      expect(BookingMode.scheduled.offersTokens, isFalse);
    });

    test('doctor detail carries the booking mode', () {
      final doctor = DoctorDetail.fromJson({
        'id': 'doc-1',
        'displayName': 'Dr. Sharma',
        'bookingMode': 'BOTH',
        'organization': {'id': 'org-1', 'name': 'ABC Clinic'},
      });
      expect(doctor.bookingMode, BookingMode.both);
      expect(doctor.toSummary().bookingMode, BookingMode.both);
    });
  });

  group('token window', () {
    test('reads the public, unauthenticated window endpoint', () async {
      final api = FakePlatformApi();
      api.routes['/api/public/doctors/doc-1/token-window'] = (_) => jsonResponse({
        'status': 'NOT_YET_OPEN',
        'bookable': false,
        'date': '2026-10-01',
        'timezone': 'Asia/Kolkata',
        'opensAt': '07:00',
        'closesAt': '11:00',
        'queueStartAt': '09:00',
        'reason': 'Token booking opens today at 07:00.',
        'errorCode': 'TOKEN_BOOKING_NOT_OPEN',
      });
      final harness = await HealthcareHarness.create(api: api);

      final window = await harness.healthcare.tokenWindow('doc-1');

      expect(window.bookable, isFalse);
      expect(window.isNotYetOpen, isTrue);
      expect(window.opensAt, '07:00');
      expect(window.timezone, 'Asia/Kolkata');
      expect(api.lastRequest.headers.containsKey('Authorization'), isFalse);
    });
  });

  group('token booking', () {
    test('posts to /patient/appointments/token without any date', () async {
      final api = FakePlatformApi();
      api.routes['/api/patient/appointments/token'] = (_) => jsonResponse({
        'appointmentId': 'appt-9',
        'entryId': 'q-9',
        'tokenNumber': 27,
        'reused': false,
        'doctorName': 'Dr. Sharma',
        'queueDate': '2026-10-01',
        'queueStartAt': '09:00',
      }, 201);
      final harness = await HealthcareHarness.create(api: api);

      final booking = await harness.appointments.bookToken(
        organizationId: 'org-1',
        doctorId: 'doc-1',
        patient: const PatientDetails(firstName: 'Priya', lastName: 'S'),
      );

      expect(booking.tokenNumber, 27);
      expect(booking.reused, isFalse);
      final body = api.lastRequest.json;
      expect(body['organizationId'], 'org-1');
      expect(body['doctorId'], 'doc-1');
      // "Today" is the server's call, in the clinic's timezone.
      expect(body.containsKey('date'), isFalse);
      expect(body.containsKey('scheduledStart'), isFalse);
      expect(body.containsKey('tokenNumber'), isFalse);
    });

    test('a repeat booking returns the existing token, flagged reused', () async {
      final api = FakePlatformApi();
      api.routes['/api/patient/appointments/token'] = (_) => jsonResponse({
        'appointmentId': 'appt-9',
        'tokenNumber': 27,
        'reused': true,
        'queueDate': '2026-10-01',
        'queueStartAt': '09:00',
      });
      final harness = await HealthcareHarness.create(api: api);

      final booking = await harness.appointments.bookToken(
        organizationId: 'org-1',
        doctorId: 'doc-1',
        patient: const PatientDetails(firstName: 'Priya', lastName: 'S'),
      );
      expect(booking.reused, isTrue);
      expect(booking.appointmentId, 'appt-9');
    });

    test('surfaces the server window refusal as a typed error', () async {
      final api = FakePlatformApi();
      api.routes['/api/patient/appointments/token'] = (_) => jsonResponse({
        'error': {
          'code': 'TOKEN_BOOKING_CLOSED',
          'message': 'Token booking closed today at 11:00.',
        },
      }, 409);
      final harness = await HealthcareHarness.create(api: api);

      await expectLater(
        harness.appointments.bookToken(
          organizationId: 'org-1',
          doctorId: 'doc-1',
          patient: const PatientDetails(firstName: 'A', lastName: 'B'),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'TOKEN_BOOKING_CLOSED')
              .having((e) => e.message, 'message', contains('11:00')),
        ),
      );
    });
  });

  group('token status', () {
    test('reads live position from the server, with no ETA', () async {
      final api = FakePlatformApi();
      api.routes['/api/patient/token-status'] = (_) => jsonResponse({
        'appointmentId': 'appt-9',
        'queueEntryId': 'q-9',
        'tokenNumber': 27,
        'state': 'WAITING',
        'ahead': 3,
        'nowServingToken': 23,
        'doctorName': 'Dr. Sharma',
        'queueDate': '2026-10-01',
        'queueStartAt': '09:00',
        'bookingKind': 'SAME_DAY_TOKEN',
        'advice': 'You are in the queue. Please wait in the waiting area.',
        'adviceTone': 'WAIT',
      });
      final harness = await HealthcareHarness.create(api: api);

      final status = await harness.appointments.tokenStatus('appt-9');

      expect(api.lastRequest.uri.queryParameters['appointmentId'], 'appt-9');
      expect(status.ahead, 3);
      expect(status.nowServingToken, 23);
      expect(status.isLive, isTrue);
    });

    test('held and finished tokens are distinguished', () {
      TokenStatus status(String state) => TokenStatus.fromJson({
        'tokenNumber': 2,
        'state': state,
        'advice': '',
      });
      expect(status('HOLD').isLive, isTrue);
      expect(status('COMPLETED').isLive, isFalse);
      expect(status('NO_SHOW').isLive, isFalse);
    });

    test('a cancelled token (entry parked as SKIPPED) is not live', () {
      final cancelled = TokenStatus.fromJson({
        'tokenNumber': 4,
        'state': 'SKIPPED',
        'appointmentStatus': 'CANCELLED',
        'advice': 'This booking was cancelled.',
      });
      expect(cancelled.isWithdrawn, isTrue);
      expect(cancelled.isLive, isFalse);
      final skipped = TokenStatus.fromJson({
        'tokenNumber': 4,
        'state': 'SKIPPED',
        'appointmentStatus': 'WAITING',
        'advice': '',
      });
      expect(skipped.isLive, isTrue);
    });
  });

  group('Appointment', () {
    test('knows a token booking from a scheduled one', () {
      final token = Appointment.fromJson({
        ...appointmentJson(),
        'bookingKind': 'SAME_DAY_TOKEN',
        'tokenDate': '2026-10-01T00:00:00.000Z',
      });
      expect(token.isToken, isTrue);
      expect(token.tokenDate, '2026-10-01');
      expect(Appointment.fromJson(appointmentJson()).isToken, isFalse);
    });

    test('HOLD is not a finished queue state', () {
      final entry = QueueEntry.fromJson({'id': 'q', 'tokenNumber': 2, 'state': 'HOLD'})!;
      expect(entry.isOnHold, isTrue);
      expect(entry.isDone, isFalse);
    });
  });
}
