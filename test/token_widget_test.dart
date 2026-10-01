import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/features/healthcare/appointment_detail_screen.dart';
import 'package:medireminder/features/healthcare/doctor_profile_screen.dart';

import 'healthcare_test_helpers.dart';

/// Renders the real token screens against the fake platform API: what the
/// patient sees comes from server values only (window, tokenNumber, state,
/// ahead, nowServingToken) — never a computed ETA or position.
void main() {
  Map<String, dynamic> windowJson({
    String status = 'OPEN',
    bool bookable = true,
    String? errorCode,
  }) => {
    'status': status,
    'bookable': bookable,
    'date': '2026-10-01',
    'timezone': 'Asia/Kolkata',
    'opensAt': '07:00',
    'closesAt': '11:00',
    'queueStartAt': '09:00',
    'reason': null,
    'errorCode': errorCode,
  };

  Future<void> pumpProfile(
    WidgetTester tester, {
    required String mode,
    required Map<String, dynamic> window,
  }) async {
    final api = FakePlatformApi();
    api.routes['/api/public/doctors/doc-1'] = (_) => jsonResponse({
      ...doctorJson(organization: {'id': 'org-1', 'name': 'ABC Clinic'}),
      'bookingMode': mode,
    });
    api.routes['/api/public/doctors/doc-1/token-window'] = (_) =>
        jsonResponse(window);
    final harness = await HealthcareHarness.create(api: api);
    await tester.pumpWidget(
      harness.wrap(const DoctorProfileScreen(doctorId: 'doc-1')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('BOTH: token card (open) and the scheduled button', (
    tester,
  ) async {
    await pumpProfile(tester, mode: 'BOTH', window: windowJson());
    expect(find.text("Today's token"), findsOneWidget);
    expect(find.text("Today's token booking is open."), findsOneWidget);
    expect(find.text("Book today's token"), findsOneWidget);
    expect(find.text('Book appointment'), findsOneWidget);
  });

  testWidgets('before opening: disabled "Booking opens at 07:00"', (
    tester,
  ) async {
    await pumpProfile(
      tester,
      mode: 'SAME_DAY_TOKEN',
      window: windowJson(
        status: 'NOT_YET_OPEN',
        bookable: false,
        errorCode: 'TOKEN_BOOKING_NOT_OPEN',
      ),
    );
    expect(find.text("Today's token booking opens at 07:00."), findsOneWidget);
    final button = find.ancestor(
      of: find.text('Booking opens at 07:00'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );
    expect(tester.widget<ButtonStyleButton>(button).onPressed, isNull);
    // Token-only doctor: no scheduled booking button.
    expect(find.text('Book appointment'), findsNothing);
  });

  testWidgets('SCHEDULED: no token card and no window request', (tester) async {
    final api = FakePlatformApi();
    api.routes['/api/public/doctors/doc-1'] = (_) => jsonResponse({
      ...doctorJson(organization: {'id': 'org-1', 'name': 'ABC Clinic'}),
      'bookingMode': 'SCHEDULED',
    });
    final harness = await HealthcareHarness.create(api: api);
    await tester.pumpWidget(
      harness.wrap(const DoctorProfileScreen(doctorId: 'doc-1')),
    );
    await tester.pumpAndSettle();
    expect(find.text("Today's token"), findsNothing);
    expect(api.hasRequestMatching('/token-window'), isFalse);
    expect(find.text('Book appointment'), findsOneWidget);
  });

  Future<FakePlatformApi> pumpToken(
    WidgetTester tester,
    Map<String, dynamic> status,
  ) async {
    final api = FakePlatformApi();
    api.routes['/api/orgs/org-1/appointments/appt-9'] = (_) => jsonResponse({
      ...appointmentJson(
        id: 'appt-9',
        status: status['appointmentStatus'] as String,
        scheduledStart: '2026-10-01T03:30:00.000Z',
        queueEntry: {
          'id': 'q-9',
          'tokenNumber': 27,
          'state': 'WAITING',
          'position': 27,
        },
      ),
      'bookingKind': 'SAME_DAY_TOKEN',
      'tokenDate': '2026-10-01T00:00:00.000Z',
    });
    api.routes['/api/patient/token-status'] = (_) => jsonResponse(status);
    final harness = await HealthcareHarness.create(api: api);
    await tester.pumpWidget(
      harness.wrap(
        const AppointmentDetailScreen(
          organizationId: 'org-1',
          organizationName: 'ABC Clinic',
          appointmentId: 'appt-9',
        ),
      ),
    );
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets(
    'my token: server ahead / now serving, no ETA, no position maths',
    (tester) async {
      await pumpToken(tester, {
        'appointmentId': 'appt-9',
        'tokenNumber': 27,
        'state': 'WAITING',
        'appointmentStatus': 'WAITING',
        'ahead': 2,
        'nowServingToken': 24,
        'queueDate': '2026-10-01',
        'queueStartAt': '09:00',
        'advice': 'You are in the queue. Please wait in the waiting area.',
        'adviceTone': 'WAIT',
      });

      expect(find.text('Your token: #27'), findsOneWidget);
      // The server said 2 — not tokenNumber - 1 (= 26).
      expect(find.text('2 patients ahead of you'), findsOneWidget);
      expect(find.textContaining('26 patients'), findsNothing);
      expect(find.text('Now serving #24'), findsOneWidget);
      expect(find.textContaining('Same-day token'), findsOneWidget);
      expect(
        find.text('You are in the queue. Please wait in the waiting area.'),
        findsOneWidget,
      );
      // Dispose so the 20 s poll timer is cancelled.
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('held token: "On hold" + see-reception advice', (tester) async {
    await pumpToken(tester, {
      'appointmentId': 'appt-9',
      'tokenNumber': 27,
      'state': 'HOLD',
      'appointmentStatus': 'WAITING',
      'ahead': 0,
      'nowServingToken': 28,
      'queueDate': '2026-10-01',
      'queueStartAt': '09:00',
      'advice': 'Your place is on hold. Please speak to reception.',
      'adviceTone': 'SEE_RECEPTION',
    });
    expect(find.text('On hold'), findsOneWidget);
    expect(
      find.text('Your place is on hold. Please speak to reception.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cancelled token shows Cancelled and stops polling', (
    tester,
  ) async {
    final api = await pumpToken(tester, {
      'appointmentId': 'appt-9',
      'tokenNumber': 27,
      'state': 'SKIPPED',
      'appointmentStatus': 'CANCELLED',
      'ahead': 0,
      'nowServingToken': null,
      'queueDate': '2026-10-01',
      'queueStartAt': '09:00',
      'advice': 'This booking was cancelled.',
      'adviceTone': 'PROBLEM',
    });
    expect(find.text('Skipped'), findsNothing);
    expect(find.text('This booking was cancelled.'), findsOneWidget);
    final before = api.requests
        .where((r) => r.uri.path.endsWith('/token-status'))
        .length;
    await tester.pump(const Duration(seconds: 45));
    final after = api.requests
        .where((r) => r.uri.path.endsWith('/token-status'))
        .length;
    expect(after, before, reason: 'no polling for a cancelled token');
  });
}
