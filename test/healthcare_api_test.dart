import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:medireminder/data/api/api_client.dart';
import 'package:medireminder/data/api/api_exception.dart';
import 'package:medireminder/data/api/token_store.dart';
import 'package:medireminder/data/models/healthcare/appointment.dart';
import 'package:medireminder/data/repositories/appointment_repository.dart';
import 'package:medireminder/services/platform_auth_service.dart';

import 'healthcare_test_helpers.dart';

void main() {
  group('ApiClient', () {
    test('identifies as a mobile client and sends the bearer token', () async {
      final api = FakePlatformApi();
      api.routes['/api/public/organizations'] = (_) =>
          jsonResponse({'data': [], 'total': 0, 'page': 1, 'pageSize': 20});
      api.routes['/api/me'] = (_) =>
          jsonResponse({'id': 'user-1', 'email': 'a@b.test'});
      final client = await healthcareClient(api);

      await client.getObject(
        '/public/organizations',
        auth: AuthMode.none,
      );

      expect(api.lastRequest.headers['X-Client'], 'app');
      // Public reads must not leak credentials.
      expect(api.lastRequest.headers.containsKey('Authorization'), isFalse);

      await client.getObject('/me', auth: AuthMode.required);
      expect(
        api.lastRequest.headers['Authorization'],
        'Bearer $kTestAccessToken',
      );
    });

    test('fails fast when a session is required but absent', () async {
      final api = FakePlatformApi();
      final client = await healthcareClient(api, signedIn: false);

      await expectLater(
        client.getList('/orgs', auth: AuthMode.required),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'NOT_AUTHENTICATED',
          ),
        ),
      );
      expect(api.requests, isEmpty);
    });

    test('maps the backend error envelope to a typed exception', () async {
      final api = FakePlatformApi();
      api.routes['/api/public/organizations/ghost'] = (_) => jsonResponse({
        'error': {'code': 'NOT_FOUND', 'message': 'Not found.'},
      }, 404);
      final client = await healthcareClient(api);

      await expectLater(
        client.getObject('/public/organizations/ghost'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'NOT_FOUND')
              .having((e) => e.status, 'status', 404),
        ),
      );
    });

    test('rotates the refresh token once on 401 and retries', () async {
      final api = FakePlatformApi();
      var myRequests = 0;
      api.routes['/api/auth/refresh'] = (_) => jsonResponse({
        'accessToken': 'access-token-2',
        'refreshToken': 'refresh-token-2',
        'tokenType': 'Bearer',
      });
      api.routes['/api/me'] = (_) {
        myRequests++;
        if (myRequests == 1) {
          return jsonResponse({
            'error': {'code': 'TOKEN_EXPIRED', 'message': 'Expired.'},
          }, 401);
        }
        return jsonResponse({'id': 'user-1', 'email': 'a@b.test'});
      };

      final store = InMemoryTokenStore();
      await store.write(
        const PlatformTokens(
          accessToken: 'stale',
          refreshToken: kTestRefreshToken,
        ),
      );
      final client = ApiClient(
        tokenStore: store,
        httpClient: api.client,
        baseUrl: () => 'https://clinic.test/api',
      );

      final me = await client.getObject('/me', auth: AuthMode.required);

      expect(me['id'], 'user-1');
      expect((await store.read())!.accessToken, 'access-token-2');
      expect(api.requests.where((r) => r.uri.path.endsWith('/auth/refresh')).length, 1);
    });

    test('forgets the session when the refresh is refused', () async {
      final api = FakePlatformApi();
      api.routes['/api/auth/refresh'] = (_) => jsonResponse({
        'error': {'code': 'REFRESH_REUSE_DETECTED', 'message': 'Reused.'},
      }, 401);
      api.routes['/api/me'] = (_) => jsonResponse({
        'error': {'code': 'TOKEN_EXPIRED', 'message': 'Expired.'},
      }, 401);

      final store = InMemoryTokenStore();
      await store.write(
        const PlatformTokens(accessToken: 'stale', refreshToken: 'old'),
      );
      final client = ApiClient(
        tokenStore: store,
        httpClient: api.client,
        baseUrl: () => 'https://clinic.test/api',
      );

      await expectLater(
        client.getObject('/me', auth: AuthMode.required),
        throwsA(
          isA<ApiException>()
              .having((e) => e.sessionExpired, 'sessionExpired', isTrue),
        ),
      );
      expect(await store.read(), isNull);
    });

    test('turns a transport failure into a friendly exception', () async {
      final api = FakePlatformApi(
        handler: (request) async => throw http.ClientException('no route'),
      );
      final client = await healthcareClient(api);

      await expectLater(
        client.getObject('/public/organizations'),
        throwsA(
          isA<ApiException>().having((e) => e.isNetworkIssue, 'network', isTrue),
        ),
      );
    });
  });

  group('HealthcareRepository', () {
    test('parses a page of publicly listed organizations', () async {
      final api = FakePlatformApi();
      api.routes['/api/public/organizations'] = (_) => jsonResponse({
        'data': [organizationJson()],
        'total': 1,
        'page': 1,
        'pageSize': 20,
      });
      final harness = await HealthcareHarness.create(api: api);

      final page = await harness.healthcare.searchOrganizations();

      expect(page.items, hasLength(1));
      expect(page.items.first.name, 'ABC Multispeciality Hospital');
      expect(page.items.first.cities, ['Jaipur']);
      expect(page.items.first.doctorCount, 2);
      expect(page.items.first.isVerified, isTrue);
      expect(page.hasMore, isFalse);
    });

    test('passes search filters straight through as query parameters', () async {
      final api = FakePlatformApi();
      api.routes['/api/public/organizations'] = (_) =>
          jsonResponse({'data': [], 'total': 0, 'page': 2, 'pageSize': 20});
      final harness = await HealthcareHarness.create(api: api);

      await harness.healthcare.searchOrganizations(
        query: 'heart',
        city: 'Jaipur',
        orgType: 'HOSPITAL',
        page: 2,
      );

      final query = api.lastRequest.uri.queryParameters;
      expect(query['q'], 'heart');
      expect(query['city'], 'Jaipur');
      expect(query['orgType'], 'HOSPITAL');
      expect(query['page'], '2');
    });

    test('parses the public organization profile with locations and doctors',
        () async {
      final api = FakePlatformApi();
      api.routes['/api/public/organizations/abc-hospital'] = (_) =>
          jsonResponse(organizationDetailJson());
      final harness = await HealthcareHarness.create(api: api);

      final detail = await harness.healthcare.organizationBySlug('abc-hospital');

      expect(detail.locations.single.name, 'Jaipur Main Branch');
      expect(detail.doctors.single.displayName, 'Dr. Amit Sharma');
      expect(detail.publicPhone, '+911410000000');
    });

    test('asks for slots on the requested day and keeps the clinic timezone',
        () async {
      final api = FakePlatformApi();
      api.routes['/api/public/doctors/doc-1/slots'] = (_) => jsonResponse({
        'slots': [
          {
            'start': '2026-09-23T04:30:00.000Z',
            'end': '2026-09-23T05:00:00.000Z',
          },
        ],
        'timezone': 'Asia/Kolkata',
        'durationMinutes': 30,
      });
      final harness = await HealthcareHarness.create(api: api);

      final availability = await harness.healthcare.doctorAvailability(
        'doc-1',
        date: DateTime(2026, 9, 23),
      );

      expect(api.lastRequest.uri.queryParameters['date'], '2026-09-23');
      expect(availability.timezone, 'Asia/Kolkata');
      expect(availability.slots.single.start.toUtc().hour, 4);
    });
  });

  group('AppointmentRepository', () {
    test('merges appointments across every clinic the patient belongs to',
        () async {
      final api = FakePlatformApi();
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
          {
            'id': 'org-2',
            'name': 'Some Clinic',
            'slug': 'some-clinic',
            'timezone': 'Asia/Kolkata',
            'role': 'CLINIC_ADMIN',
            'isActive': true,
          },
        ],
      });
      api.routes['/api/orgs/org-1/appointments'] = (_) =>
          jsonResponse({'data': [appointmentJson()]});
      api.routes['/api/orgs/org-2/appointments'] = (_) => jsonResponse({
        'data': [appointmentJson(id: 'appt-2', organizationId: 'org-2')],
      });
      api.routes['/api/public/organizations/abc-hospital'] = (_) =>
          jsonResponse(organizationDetailJson());
      api.routes['/api/public/organizations/some-clinic'] = (_) =>
          jsonResponse(
            organizationDetailJson(
              id: 'org-2',
              slug: 'some-clinic',
              name: 'Some Clinic',
            ),
          );
      final harness = await HealthcareHarness.create(api: api);

      final rows = await harness.appointments.myAppointments();

      // Only the clinic where this account is a PATIENT is queried.
      expect(harness.api.hasRequestMatching('/orgs/org-1/appointments'), isTrue);
      expect(harness.api.hasRequestMatching('/orgs/org-2/appointments'), isFalse);
      expect(rows.single.appointment.id, 'appt-1');
      expect(rows.single.organization.name, 'ABC Hospital');
      expect(rows.single.location?.name, 'Jaipur Main Branch');
    });

    test('books through /patient/appointments with the picked slot', () async {
      final api = FakePlatformApi();
      api.routes['/api/patient/appointments'] = (_) =>
          jsonResponse(appointmentJson());
      final harness = await HealthcareHarness.create(api: api);

      final appointment = await harness.appointments.book(
        organizationId: 'org-1',
        doctorId: 'doc-1',
        scheduledStart: DateTime.utc(2026, 9, 23, 4, 30),
        locationId: 'loc-1',
        reason: 'Fever',
        patient: const PatientDetails(
          firstName: 'Ritesh',
          lastName: 'Kumar',
          phone: '9999999999',
        ),
      );

      final body = api.lastRequest.json;
      expect(api.lastRequest.method, 'POST');
      expect(body['organizationId'], 'org-1');
      expect(body['doctorId'], 'doc-1');
      expect(body['locationId'], 'loc-1');
      expect(body['scheduledStart'], '2026-09-23T04:30:00.000Z');
      expect(body['patient'], {
        'firstName': 'Ritesh',
        'lastName': 'Kumar',
        'phone': '9999999999',
      });
      expect(appointment.status, AppointmentStatus.confirmed);
    });

    test('surfaces a taken slot as a slot-taken error', () async {
      final api = FakePlatformApi();
      api.routes['/api/patient/appointments'] = (_) => jsonResponse({
        'error': {
          'code': 'APPOINTMENT_SLOT_TAKEN',
          'message': 'That slot was just booked.',
        },
      }, 409);
      final harness = await HealthcareHarness.create(api: api);

      await expectLater(
        harness.appointments.book(
          organizationId: 'org-1',
          doctorId: 'doc-1',
          scheduledStart: DateTime.utc(2026, 9, 23, 4, 30),
          patient: const PatientDetails(firstName: 'A', lastName: 'B'),
        ),
        throwsA(
          isA<ApiException>().having((e) => e.isSlotTaken, 'slotTaken', isTrue),
        ),
      );
    });

    test('returns the replacement appointment when rescheduling', () async {
      final api = FakePlatformApi();
      api.routes['/api/orgs/org-1/appointments/appt-1/reschedule'] = (_) =>
          jsonResponse({
            'previousId': 'appt-1',
            'appointment': appointmentJson(
              id: 'appt-2',
              scheduledStart: '2026-09-24T04:30:00.000Z',
            ),
          });
      final harness = await HealthcareHarness.create(api: api);

      final moved = await harness.appointments.reschedule(
        organizationId: 'org-1',
        appointmentId: 'appt-1',
        scheduledStart: DateTime.utc(2026, 9, 24, 4, 30),
      );

      expect(moved.id, 'appt-2');
      expect(
        api.lastRequest.json['scheduledStart'],
        '2026-09-24T04:30:00.000Z',
      );
    });

    test('reads a queue ticket with its token and position', () async {
      final api = FakePlatformApi();
      api.routes['/api/orgs/org-1/appointments/appt-1'] = (_) => jsonResponse(
        appointmentJson(
          status: 'WAITING',
          queueEntry: {
            'id': 'queue-1',
            'tokenNumber': 12,
            'state': 'WAITING',
            'position': 4,
            'calledAt': null,
          },
        ),
      );
      final harness = await HealthcareHarness.create(api: api);

      final appointment = await harness.appointments.appointment(
        organizationId: 'org-1',
        appointmentId: 'appt-1',
      );

      expect(appointment.queueEntry!.tokenNumber, 12);
      expect(appointment.queueEntry!.position, 4);
      expect(appointment.queueEntry!.isWaiting, isTrue);
    });
  });

  group('PlatformAuthService', () {
    test('signs in with the app client and loads the profile', () async {
      final api = FakePlatformApi();
      api.routes['/api/auth/login'] = (_) => jsonResponse({
        'accessToken': 'access-token-1',
        'refreshToken': 'refresh-token-1',
        'tokenType': 'Bearer',
      });
      api.routes['/api/me'] = (_) => jsonResponse({
        'id': 'user-1',
        'email': 'a@b.test',
        'fullName': 'Ritesh Kumar',
        'phone': '9999999999',
      });
      final harness = await HealthcareHarness.create(api: api, signedIn: false);

      final ok = await harness.account.signIn(
        email: 'a@b.test',
        password: 'password1234',
      );

      expect(ok, isTrue);
      expect(harness.account.isSignedIn, isTrue);
      expect(harness.account.user!.firstName, 'Ritesh');
      expect(harness.account.user!.lastName, 'Kumar');
    });

    test('registers then signs in (register returns no tokens)', () async {
      final api = FakePlatformApi();
      api.routes['/api/auth/register'] =
          (_) => jsonResponse({'userId': 'user-1'}, 201);
      api.routes['/api/auth/login'] = (_) => jsonResponse({
        'accessToken': 'a',
        'refreshToken': 'r',
      });
      api.routes['/api/me'] = (_) =>
          jsonResponse({'id': 'user-1', 'email': 'a@b.test'});
      final harness = await HealthcareHarness.create(api: api, signedIn: false);

      final ok = await harness.account.register(
        fullName: 'Ritesh Kumar',
        email: 'a@b.test',
        password: 'password1234',
      );

      expect(ok, isTrue);
      expect(
        api.requests.map((r) => r.uri.path).toList(),
        ['/api/auth/register', '/api/auth/login', '/api/me'],
      );
    });

    test('keeps the failure message when the password is wrong', () async {
      final api = FakePlatformApi();
      api.routes['/api/auth/login'] = (_) => jsonResponse({
        'error': {
          'code': 'INVALID_CREDENTIALS',
          'message': 'Invalid email or password.',
        },
      }, 401);
      final harness = await HealthcareHarness.create(api: api, signedIn: false);

      final ok = await harness.account.signIn(
        email: 'a@b.test',
        password: 'nope',
      );

      expect(ok, isFalse);
      expect(harness.account.isSignedIn, isFalse);
      expect(harness.account.lastError?.code, 'INVALID_CREDENTIALS');
    });

    test('restore signs out when the stored session is dead', () async {
      final api = FakePlatformApi();
      api.routes['/api/me'] = (_) => jsonResponse({
        'error': {'code': 'NOT_AUTHENTICATED', 'message': 'Authentication required.'},
      }, 401);
      final harness = await HealthcareHarness.create(api: api);

      await harness.account.restore();

      expect(harness.account.isSignedIn, isFalse);
      expect(harness.account.status, PlatformAuthStatus.signedOut);
    });
  });
}
