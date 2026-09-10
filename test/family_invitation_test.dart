import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/services/sync/invitation_service.dart';

void main() {
  group('FamilyRole', () {
    test('normalizes legacy strings to the two-role model', () {
      expect(FamilyRole.normalize('owner'), FamilyRole.owner);
      expect(FamilyRole.normalize('primary'), FamilyRole.owner);
      expect(FamilyRole.normalize('admin'), FamilyRole.owner);
      expect(FamilyRole.normalize('member'), FamilyRole.member);
      expect(FamilyRole.normalize('watcher'), FamilyRole.member);
      expect(FamilyRole.normalize(null), FamilyRole.member);
      expect(FamilyRole.normalize('anything-else'), FamilyRole.member);
    });
  });

  group('FamilyPermissions', () {
    test('defaults to fully private', () {
      const p = FamilyPermissions();
      expect(p.shareMedicines, isFalse);
      expect(p.shareMissedAlerts, isFalse);
    });

    test('round-trips through a map', () {
      const p = FamilyPermissions(shareMedicines: true);
      final back = FamilyPermissions.fromMap(p.toMap());
      expect(back.shareMedicines, isTrue);
      expect(back.shareMissedAlerts, isFalse);
      // Missing / null map => private.
      expect(FamilyPermissions.fromMap(null).shareMedicines, isFalse);
    });
  });

  group('QR payload', () {
    test('carries only a token — no household id, uid, email or medical data',
        () {
      final data = InvitationData(
        token: 'abc123token',
        creatorName: 'Alice',
        expiresAt: DateTime.utc(2030),
      );
      final payload = jsonDecode(data.toQrPayload()) as Map<String, dynamic>;
      expect(payload.keys.toSet(), {'type', 'token', 'v'});
      expect(payload['type'], 'dosewise_invite');
      expect(payload['token'], 'abc123token');
      // creatorName is metadata for the sender's screen, never serialised.
      expect(data.toQrPayload().contains('Alice'), isFalse);
    });

    test('parses a valid payload and rejects anything else', () {
      final ok = InvitationData.fromQrPayload(
        '{"type":"dosewise_invite","token":"t0k3n","v":1}',
      );
      expect(ok, isNotNull);
      expect(ok!.token, 't0k3n');

      expect(InvitationData.fromQrPayload('https://example.com'), isNull);
      expect(
        InvitationData.fromQrPayload('{"type":"other","token":"x"}'),
        isNull,
      );
      expect(
        InvitationData.fromQrPayload('{"type":"dosewise_invite","token":""}'),
        isNull,
      );
      expect(InvitationData.fromQrPayload('not json'), isNull);
    });
  });
}
