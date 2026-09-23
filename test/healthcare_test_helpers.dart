import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medireminder/core/localization/generated/app_localizations.dart';
import 'package:medireminder/data/api/api_client.dart';
import 'package:medireminder/data/api/token_store.dart';
import 'package:medireminder/data/repositories/appointment_repository.dart';
import 'package:medireminder/data/repositories/healthcare_repository.dart';
import 'package:medireminder/services/platform_auth_service.dart';
import 'package:provider/provider.dart';

/// Records every request the app makes, so tests can assert on URL, headers
/// and body instead of guessing.
class RecordedRequest {
  RecordedRequest(this.method, this.uri, this.headers, this.body);

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;

  Map<String, dynamic> get json =>
      body.isEmpty ? const {} : jsonDecode(body) as Map<String, dynamic>;
}

/// A fake platform API: routes requests to canned responses and records them.
class FakePlatformApi {
  FakePlatformApi({this.handler});

  /// Optional override for full control; otherwise [respond] is used.
  final Future<http.Response> Function(http.Request request)? handler;

  final List<RecordedRequest> requests = [];

  /// Path (without query) → response factory.
  final Map<String, http.Response Function(http.Request request)> routes = {};

  /// Fails the next [failNextRequests] calls with 500 (for retry tests).
  int failNextRequests = 0;

  http.Client get client => MockClient((request) async {
    requests.add(
      RecordedRequest(
        request.method,
        request.url,
        Map.of(request.headers),
        request.body,
      ),
    );
    if (handler != null) return handler!(request);
    if (failNextRequests > 0) {
      failNextRequests--;
      return http.Response(
        jsonEncode({
          'error': {'code': 'INTERNAL', 'message': 'Boom.'},
        }),
        500,
        headers: {'content-type': 'application/json'},
      );
    }
    final responder = routes[request.url.path];
    if (responder == null) {
      return http.Response(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'Not found.'},
        }),
        404,
        headers: {'content-type': 'application/json'},
      );
    }
    return responder(request);
  });

  RecordedRequest get lastRequest => requests.last;

  bool hasRequestMatching(String pathFragment) =>
      requests.any((r) => r.uri.path.contains(pathFragment));
}

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

/// A platform session in place, as if the user had signed in.
const String kTestAccessToken = 'access-token-1';
const String kTestRefreshToken = 'refresh-token-1';

Future<ApiClient> healthcareClient(
  FakePlatformApi api, {
  bool signedIn = true,
}) async {
  final store = InMemoryTokenStore();
  if (signedIn) {
    await store.write(
      const PlatformTokens(
        accessToken: kTestAccessToken,
        refreshToken: kTestRefreshToken,
      ),
    );
  }
  return ApiClient(
    tokenStore: store,
    httpClient: api.client,
    baseUrl: () => 'https://clinic.test/api',
  );
}

/// Everything the healthcare screens need, wired to one fake API.
class HealthcareHarness {
  HealthcareHarness({
    required this.api,
    required this.client,
    required this.healthcare,
    required this.appointments,
    required this.account,
  });

  final FakePlatformApi api;
  final ApiClient client;
  final HealthcareRepository healthcare;
  final AppointmentRepository appointments;
  final PlatformAuthService account;

  static Future<HealthcareHarness> create({
    FakePlatformApi? api,
    bool signedIn = true,
  }) async {
    final fake = api ?? FakePlatformApi();
    final client = await healthcareClient(fake, signedIn: signedIn);
    final healthcare = HealthcareRepository(client: client);
    final appointments = AppointmentRepository(
      client: client,
      healthcare: healthcare,
    );
    final account = PlatformAuthService(client: client);
    return HealthcareHarness(
      api: fake,
      client: client,
      healthcare: healthcare,
      appointments: appointments,
      account: account,
    );
  }

  /// Wraps a widget in the providers and localizations the real app supplies.
  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        Provider<HealthcareRepository>.value(value: healthcare),
        Provider<AppointmentRepository>.value(value: appointments),
        ChangeNotifierProvider<PlatformAuthService>.value(value: account),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    );
  }
}

/// A public organization summary, exactly as `/api/public/organizations`
/// returns it.
Map<String, dynamic> organizationJson({
  String id = 'org-1',
  String slug = 'abc-hospital',
  String name = 'ABC Multispeciality Hospital',
  String? orgType = 'HOSPITAL',
  String? tagline = 'Care you can trust',
  String? verificationStatus = 'VERIFIED',
  List<String> cities = const ['Jaipur'],
  int doctorCount = 2,
}) => {
  'id': id,
  'slug': slug,
  'name': name,
  'tagline': tagline,
  'logoUrl': null,
  'orgType': orgType,
  'verificationStatus': verificationStatus,
  'locations': [
    for (final city in cities) {'city': city},
  ],
  '_count': {'doctorProfiles': doctorCount},
};

Map<String, dynamic> doctorJson({
  String id = 'doc-1',
  String displayName = 'Dr. Amit Sharma',
  String? specialty = 'Cardiologist',
  int? yearsOfExperience = 15,
  List<String> languages = const ['Hindi', 'English'],
  int? consultationFeeMinor = 50000,
  Map<String, dynamic>? organization,
}) => {
  'id': id,
  'displayName': displayName,
  'specialty': specialty,
  'photoUrl': null,
  'yearsOfExperience': yearsOfExperience,
  'languages': languages,
  'consultationFeeMinor': consultationFeeMinor,
  if (organization != null) 'organization': organization,
};

Map<String, dynamic> organizationDetailJson({
  String id = 'org-1',
  String slug = 'abc-hospital',
  String name = 'ABC Multispeciality Hospital',
  List<Map<String, dynamic>>? locations,
  List<Map<String, dynamic>>? doctors,
}) => {
  'id': id,
  'slug': slug,
  'name': name,
  'tagline': 'Care you can trust',
  'about': 'A multispeciality hospital in Jaipur.',
  'logoUrl': null,
  'coverImageUrl': null,
  'orgType': 'HOSPITAL',
  'publicPhone': '+911410000000',
  'publicEmail': 'care@abc.test',
  'website': 'https://abc.test',
  'verificationStatus': 'VERIFIED',
  'locations': locations ??
      [
        {
          'id': 'loc-1',
          'name': 'Jaipur Main Branch',
          'addressLine1': '12 MG Road',
          'city': 'Jaipur',
          'state': 'Rajasthan',
          'postalCode': '302001',
          'country': 'India',
          'phone': '+911410000000',
        },
      ],
  'doctorProfiles': doctors ?? [doctorJson()],
};

Map<String, dynamic> appointmentJson({
  String id = 'appt-1',
  String organizationId = 'org-1',
  String doctorId = 'doc-1',
  String? locationId = 'loc-1',
  String status = 'CONFIRMED',
  String scheduledStart = '2026-09-23T04:30:00.000Z',
  String? reason,
  Map<String, dynamic>? queueEntry,
}) => {
  'id': id,
  'organizationId': organizationId,
  'patientId': 'patient-1',
  'doctorId': doctorId,
  'locationId': locationId,
  'appointmentTypeId': null,
  'scheduledStart': scheduledStart,
  'scheduledEnd': '2026-09-23T05:00:00.000Z',
  'timezone': 'Asia/Kolkata',
  'status': status,
  'reason': reason,
  'notes': null,
  'cancelledAt': null,
  'cancellationReason': null,
  'rescheduledFromId': null,
  'doctor': {'id': doctorId, 'displayName': 'Dr. Amit Sharma'},
  'patient': {'id': 'patient-1', 'firstName': 'Ritesh', 'lastName': 'Kumar'},
  if (queueEntry != null) 'queueEntry': queueEntry,
};
