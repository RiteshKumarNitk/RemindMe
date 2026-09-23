import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/features/healthcare/appointments_screen.dart';
import 'package:medireminder/features/healthcare/healthcare_home_screen.dart';
import 'package:medireminder/features/healthcare/slot_picker_screen.dart';
import 'package:medireminder/features/healthcare/widgets/home_care_section.dart';

import 'healthcare_test_helpers.dart';

void main() {
  testWidgets('discovery lists the organizations the API publishes', (
    tester,
  ) async {
    final api = FakePlatformApi();
    api.routes['/api/public/organizations'] = (_) => jsonResponse({
      'data': [
        organizationJson(),
        organizationJson(
          id: 'org-2',
          slug: 'sunrise-clinic',
          name: 'Sunrise Clinic',
          orgType: 'CLINIC',
          verificationStatus: null,
          cities: ['Jaipur'],
          doctorCount: 1,
        ),
      ],
      'total': 2,
      'page': 1,
      'pageSize': 20,
    });
    final harness = await HealthcareHarness.create(api: api);

    await tester.pumpWidget(
      harness.wrap(const HealthcareHomeScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABC Multispeciality Hospital'), findsOneWidget);
    expect(find.text('Sunrise Clinic'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('2 doctors'), findsOneWidget);
    expect(find.text('1 doctor'), findsOneWidget);
  });

  testWidgets('discovery shows an intentional empty state, not a blank screen', (
    tester,
  ) async {
    final api = FakePlatformApi();
    api.routes['/api/public/organizations'] = (_) =>
        jsonResponse({'data': [], 'total': 0, 'page': 1, 'pageSize': 20});
    final harness = await HealthcareHarness.create(api: api);

    await tester.pumpWidget(harness.wrap(const HealthcareHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No healthcare providers found'), findsOneWidget);
    expect(find.textContaining('Try a different name'), findsOneWidget);
  });

  testWidgets('discovery shows a friendly error and retries', (tester) async {
    final api = FakePlatformApi();
    api.routes['/api/public/organizations'] = (_) => jsonResponse({
      'error': {'code': 'INTERNAL', 'message': 'Boom.'},
    }, 500);
    final harness = await HealthcareHarness.create(api: api);

    await tester.pumpWidget(harness.wrap(const HealthcareHomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text("We couldn't load this"), findsOneWidget);
    expect(find.textContaining('Boom'), findsNothing); // no raw API text

    // Recover, then retry from the error state.
    api.routes['/api/public/organizations'] = (_) => jsonResponse({
      'data': [organizationJson()],
      'total': 1,
      'page': 1,
      'pageSize': 20,
    });
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('ABC Multispeciality Hospital'), findsOneWidget);
  });

  testWidgets('slots render in the clinic timezone, not the phone timezone', (
    tester,
  ) async {
    final api = FakePlatformApi();
    api.routes['/api/public/doctors/doc-1/slots'] = (_) => jsonResponse({
      'slots': [
        {
          'start': '2030-09-23T04:30:00.000Z',
          'end': '2030-09-23T05:00:00.000Z',
        },
      ],
      'timezone': 'Asia/Kolkata',
      'durationMinutes': 30,
    });
    final harness = await HealthcareHarness.create(api: api);

    await tester.pumpWidget(
      harness.wrap(
        const SlotPickerScreen(
          doctorId: 'doc-1',
          doctorName: 'Dr. Amit Sharma',
          organizationId: 'org-1',
          organizationName: 'ABC Hospital',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 04:30 UTC is 10:00 in Asia/Kolkata.
    expect(find.text('10:00 AM'), findsOneWidget);
    expect(find.textContaining("clinic's time zone"), findsOneWidget);
  });

  testWidgets('a day with no free slots explains itself', (tester) async {
    final api = FakePlatformApi();
    api.routes['/api/public/doctors/doc-1/slots'] = (_) => jsonResponse({
      'slots': [],
      'timezone': 'Asia/Kolkata',
      'durationMinutes': 30,
    });
    final harness = await HealthcareHarness.create(api: api);

    await tester.pumpWidget(
      harness.wrap(
        const SlotPickerScreen(
          doctorId: 'doc-1',
          doctorName: 'Dr. Amit Sharma',
          organizationId: 'org-1',
          organizationName: 'ABC Hospital',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No available appointments'), findsOneWidget);
    expect(find.textContaining('Try another date'), findsOneWidget);
  });

  testWidgets('appointments ask for a sign-in instead of showing nothing', (
    tester,
  ) async {
    final harness = await HealthcareHarness.create(signedIn: false);

    await tester.pumpWidget(harness.wrap(const AppointmentsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sign in to see your appointments'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(harness.api.requests, isEmpty);
  });

  testWidgets('appointments list real rows from the patient clinics', (
    tester,
  ) async {
    final api = FakePlatformApi();
    api.routes['/api/me'] =
        (_) => jsonResponse({'id': 'user-1', 'email': 'a@b.test'});
    api.routes['/api/orgs'] = (_) => jsonResponse({
      'data': [
        {
          'id': 'org-1',
          'name': 'ABC Hospital',
          'slug': 'abc-hospital',
          'timezone': 'Asia/Kolkata',
          'role': 'PATIENT',
          'isActive': true,
        },
      ],
    });
    api.routes['/api/orgs/org-1/appointments'] = (_) => jsonResponse({
      'data': [appointmentJson()],
    });
    api.routes['/api/public/organizations/abc-hospital'] = (_) =>
        jsonResponse(organizationDetailJson());
    final harness = await HealthcareHarness.create(api: api);
    await harness.account.restore();

    await tester.pumpWidget(harness.wrap(const AppointmentsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Amit Sharma'), findsOneWidget);
    expect(find.text('ABC Hospital · Jaipur Main Branch'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('home care section offers discovery and the next appointment', (
    tester,
  ) async {
    final api = FakePlatformApi();
    api.routes['/api/me'] =
        (_) => jsonResponse({'id': 'user-1', 'email': 'a@b.test'});
    api.routes['/api/orgs'] = (_) => jsonResponse({
      'data': [
        {
          'id': 'org-1',
          'name': 'ABC Hospital',
          'slug': 'abc-hospital',
          'timezone': 'Asia/Kolkata',
          'role': 'PATIENT',
          'isActive': true,
        },
      ],
    });
    api.routes['/api/orgs/org-1/appointments'] = (_) => jsonResponse({
      'data': [
        appointmentJson(
          scheduledStart: DateTime.now()
              .toUtc()
              .add(const Duration(days: 2))
              .toIso8601String(),
        ),
      ],
    });
    api.routes['/api/public/organizations/abc-hospital'] = (_) =>
        jsonResponse(organizationDetailJson());
    final harness = await HealthcareHarness.create(api: api);
    await harness.account.restore();

    await tester.pumpWidget(
      harness.wrap(const Scaffold(body: HomeCareSection())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find healthcare'), findsOneWidget);
    expect(find.text('Upcoming appointment'), findsOneWidget);
    expect(find.text('Dr. Amit Sharma'), findsOneWidget);
  });

  testWidgets('home care section asks a signed-out user to sign in', (
    tester,
  ) async {
    final harness = await HealthcareHarness.create(signedIn: false);

    await tester.pumpWidget(
      harness.wrap(const Scaffold(body: HomeCareSection())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find healthcare'), findsOneWidget);
    expect(find.text('Sign in to see your appointments'), findsOneWidget);
    expect(harness.api.requests, isEmpty);
  });
}
