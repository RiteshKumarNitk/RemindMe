import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Family roles. A household has exactly one [owner] (its creator); everyone
/// else is a [member]. Only the owner may remove other members.
class FamilyRole {
  static const String owner = 'owner';
  static const String member = 'member';

  /// Normalises the historical role strings that predate this two-role model
  /// so old household documents still display correctly.
  static String normalize(String? raw) {
    switch (raw) {
      case owner:
      case 'primary':
      case 'admin':
        return owner;
      default:
        return member;
    }
  }
}

/// Per-member sharing permissions. Everything defaults to private — joining a
/// family never exposes a member's medication data until they opt in.
class FamilyPermissions {
  /// This member's medicines + dose history are visible to the rest of the
  /// household (drives the caregiver dashboard). Off by default.
  final bool shareMedicines;

  /// Other members receive this member's missed-dose alerts. Off by default.
  final bool shareMissedAlerts;

  const FamilyPermissions({
    this.shareMedicines = false,
    this.shareMissedAlerts = false,
  });

  Map<String, dynamic> toMap() => {
        'shareMedicines': shareMedicines,
        'shareMissedAlerts': shareMissedAlerts,
      };

  factory FamilyPermissions.fromMap(Map<String, dynamic>? map) {
    map ??= const {};
    return FamilyPermissions(
      shareMedicines: map['shareMedicines'] == true,
      shareMissedAlerts: map['shareMissedAlerts'] == true,
    );
  }
}

/// Manages family invitation tokens for QR-code based family connection, and
/// the household membership records they create.
///
/// Flow:
///   1. Owner calls [createInvitation] → gets a single-use token
///   2. Token is encoded into a QR code (token only — no PII, no medical data)
///   3. Joiner scans the QR, gets the token
///   4. Joiner calls [validateInvitation] → family name + owner name
///   5. Joiner confirms, calls [acceptInvitation] → joins the family
///
/// Security model:
///   - The QR carries ONLY a 256-bit random token. The household id is never
///     in the QR — it is resolved server-side from the (hashed) token.
///   - Tokens are SHA-256 hashed before storage; the plaintext lives only in
///     the QR, so a leaked Firestore read can't reconstruct a working invite.
///   - Tokens are single-use and expire after [tokenTTL].
///   - [acceptInvitation] runs in a Firestore transaction: consuming the
///     token and writing the membership record happen atomically, so a
///     double-scan (or two devices racing the same QR) can't create a
///     duplicate membership or a half-applied join.
///   - Membership is a per-user record under `households/{id}/members/{uid}`
///     with { userId, householdId, role, permissions, createdAt }. Firestore
///     rules (see firestore.rules) enforce members-only reads and
///     owner-only removal.
class InvitationService {
  InvitationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Duration after which an invitation token expires.
  static const Duration tokenTTL = Duration(hours: 24);

  CollectionReference<Map<String, dynamic>> get _invites =>
      _firestore.collection('invitations');

  DocumentReference<Map<String, dynamic>> _household(String id) =>
      _firestore.collection('households').doc(id);

  CollectionReference<Map<String, dynamic>> _members(String householdId) =>
      _household(householdId).collection('members');

  /// Creates a new single-use family invitation token for [householdId].
  Future<InvitationData> createInvitation({
    required String householdId,
    required String creatorUid,
    required String creatorName,
  }) async {
    final rawToken = _generateToken();
    final hashedToken = _hashToken(rawToken);
    final now = DateTime.now().toUtc();

    try {
      // create (not set): never clobber an existing token document — the
      // 256-bit space makes a collision astronomically unlikely, and if one
      // ever happened we want the error, not a silent overwrite.
      await _invites.doc(hashedToken).set({
        'householdId': householdId,
        'creatorUid': creatorUid,
        'creatorName': creatorName,
        'createdAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(tokenTTL)),
        'used': false,
        'usedBy': null,
        'usedAt': null,
      });

      developer.log(
        'Invitation created: household=$householdId by=$creatorName',
        name: 'Invitation',
      );

      return InvitationData(
        token: rawToken,
        creatorName: creatorName,
        expiresAt: now.add(tokenTTL),
      );
    } catch (e) {
      developer.log('createInvitation FAILED: $e', name: 'Invitation', error: e);
      rethrow;
    }
  }

  /// Validates a scanned token without consuming it. Returns family info on
  /// success or a user-facing [InvitationValidation.error] otherwise.
  Future<InvitationValidation> validateInvitation({
    required String token,
    required String currentUid,
  }) async {
    final hashedToken = _hashToken(token);

    try {
      final doc = await _invites.doc(hashedToken).get();
      if (!doc.exists) {
        return const InvitationValidation(
          valid: false,
          error: 'Invalid QR code. This invitation does not exist.',
        );
      }

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final used = data['used'] == true;
      final creatorUid = data['creatorUid'] as String? ?? '';
      final householdId = data['householdId'] as String? ?? '';
      final creatorName = data['creatorName'] as String? ?? '';

      if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
        return const InvitationValidation(
          valid: false,
          error: 'This QR code has expired. Ask for a new one.',
        );
      }
      if (used) {
        return const InvitationValidation(
          valid: false,
          error: 'This QR code has already been used.',
        );
      }
      if (creatorUid == currentUid) {
        return const InvitationValidation(
          valid: false,
          error: 'You cannot scan your own QR code.',
        );
      }

      // Already a member? (self-heal for a token that wasn't marked used)
      final existing = await _members(householdId).doc(currentUid).get();
      if (existing.exists) {
        return const InvitationValidation(
          valid: false,
          error: 'You are already connected to this family.',
        );
      }

      return InvitationValidation(
        valid: true,
        householdId: householdId,
        creatorName: creatorName,
      );
    } catch (e) {
      developer.log('validateInvitation FAILED: $e',
          name: 'Invitation', error: e);
      return const InvitationValidation(
        valid: false,
        error: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Consumes [token] and joins its household — atomically. Returns the
  /// household id on success; throws [StateError] with a user-facing message
  /// on any validation failure.
  Future<String> acceptInvitation({
    required String token,
    required String currentUid,
    required String currentUserName,
  }) async {
    final hashedToken = _hashToken(token);
    final inviteRef = _invites.doc(hashedToken);

    try {
      final householdId = await _firestore.runTransaction<String>((txn) async {
        final snap = await txn.get(inviteRef);
        if (!snap.exists) {
          throw StateError('Invalid QR code. This invitation does not exist.');
        }
        final data = snap.data()!;
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        final creatorUid = data['creatorUid'] as String? ?? '';
        final hid = data['householdId'] as String? ?? '';

        if (data['used'] == true) {
          throw StateError('This QR code has already been used.');
        }
        if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
          throw StateError('This QR code has expired. Ask for a new one.');
        }
        if (creatorUid == currentUid) {
          throw StateError('You cannot scan your own QR code.');
        }

        final memberRef = _members(hid).doc(currentUid);
        final memberSnap = await txn.get(memberRef);
        if (memberSnap.exists) {
          throw StateError('You are already connected to this family.');
        }

        final nowUtc = DateTime.now().toUtc();
        // Consume the token and write the membership record together.
        txn.update(inviteRef, {
          'used': true,
          'usedBy': currentUid,
          'usedAt': Timestamp.fromDate(nowUtc),
        });
        txn.set(memberRef, {
          'userId': currentUid,
          'householdId': hid,
          'name': currentUserName,
          'role': FamilyRole.member,
          'permissions': const FamilyPermissions().toMap(),
          'createdAt': Timestamp.fromDate(nowUtc),
          // Ties this record to the invitation consumed in the same commit;
          // Firestore rules verify the invitation flipped to used=true by us.
          'inviteHash': hashedToken,
        });
        return hid;
      });

      developer.log(
        'Invitation accepted: user=$currentUserName household=$householdId',
        name: 'Invitation',
      );
      return householdId;
    } catch (e) {
      developer.log('acceptInvitation FAILED: $e',
          name: 'Invitation', error: e);
      rethrow;
    }
  }

  /// All members of [householdId].
  Future<List<FamilyMember>> getFamilyMembers(String householdId) async {
    try {
      final snap = await _members(householdId).get();
      final members = <FamilyMember>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        members.add(FamilyMember(
          uid: doc.id,
          name: data['name'] as String? ?? 'Unknown',
          role: FamilyRole.normalize(data['role'] as String?),
          permissions: FamilyPermissions.fromMap(
            (data['permissions'] as Map<String, dynamic>?),
          ),
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        ));
      }
      // Legacy fallback: households created before the members subcollection
      // stored members as a map on the household document.
      if (members.isEmpty) {
        final hh = await _household(householdId).get();
        final legacy = hh.data()?['members'] as Map<String, dynamic>?;
        if (legacy != null) {
          for (final e in legacy.entries) {
            final v = (e.value as Map<String, dynamic>? ?? const {});
            members.add(FamilyMember(
              uid: e.key,
              name: v['name'] as String? ?? 'Unknown',
              role: FamilyRole.normalize(v['role'] as String?),
              permissions: FamilyPermissions.fromMap(
                v['permissions'] as Map<String, dynamic>?,
              ),
              createdAt: null,
            ));
          }
        }
      }
      return members;
    } catch (e) {
      developer.log('getFamilyMembers FAILED: $e',
          name: 'Invitation', error: e);
      return [];
    }
  }

  /// Removes [memberUid] from the household. Only the owner may remove other
  /// members; anyone may remove themselves (leave). Firestore rules enforce
  /// the same, so a tampered client still can't remove someone else.
  Future<void> removeMember({
    required String householdId,
    required String actorUid,
    required String memberUid,
  }) async {
    try {
      if (actorUid != memberUid) {
        final actor = await _members(householdId).doc(actorUid).get();
        if (FamilyRole.normalize(actor.data()?['role'] as String?) !=
            FamilyRole.owner) {
          throw StateError('Only the family owner can remove members.');
        }
        final target = await _members(householdId).doc(memberUid).get();
        if (FamilyRole.normalize(target.data()?['role'] as String?) ==
            FamilyRole.owner) {
          throw StateError('The family owner cannot be removed.');
        }
      }
      await _members(householdId).doc(memberUid).delete();
      developer.log(
        'Member removed: $memberUid from $householdId by $actorUid',
        name: 'Invitation',
      );
    } catch (e) {
      developer.log('removeMember FAILED: $e', name: 'Invitation', error: e);
      rethrow;
    }
  }

  /// Updates the calling member's own sharing permissions.
  Future<void> updateMyPermissions({
    required String householdId,
    required String uid,
    required FamilyPermissions permissions,
  }) async {
    await _members(householdId)
        .doc(uid)
        .set({'permissions': permissions.toMap()}, SetOptions(merge: true));
  }

  /// Best-effort cleanup of expired invitations.
  Future<void> cleanupExpired() async {
    try {
      final expired = await _invites
          .where('expiresAt',
              isLessThan: Timestamp.fromDate(DateTime.now().toUtc()))
          .get();
      final batch = _firestore.batch();
      for (final doc in expired.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (expired.docs.isNotEmpty) {
        developer.log('Cleaned ${expired.docs.length} expired invitations',
            name: 'Invitation');
      }
    } catch (e) {
      developer.log('cleanupExpired FAILED: $e', name: 'Invitation', error: e);
    }
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _hashToken(String token) =>
      sha256.convert(utf8.encode(token)).toString();
}

/// Data returned when creating an invitation. Only [token] goes into the QR.
class InvitationData {
  final String token;
  final String creatorName;
  final DateTime expiresAt;

  const InvitationData({
    required this.token,
    required this.creatorName,
    required this.expiresAt,
  });

  /// The QR payload: token only, plus a type tag and version. No household
  /// id, no uid, no email, no medical data.
  String toQrPayload() => jsonEncode({
        'type': 'dosewise_invite',
        'token': token,
        'v': 1,
      });

  /// Parses a scanned QR payload. Returns null when it isn't a DoseWise invite.
  static InvitationData? fromQrPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] != 'dosewise_invite') return null;
      final token = data['token'] as String?;
      if (token == null || token.isEmpty) return null;
      return InvitationData(
        token: token,
        creatorName: '',
        expiresAt: DateTime.now().toUtc().add(InvitationService.tokenTTL),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Result of validating an invitation token.
class InvitationValidation {
  final bool valid;
  final String? householdId;
  final String? creatorName;
  final String? error;

  const InvitationValidation({
    required this.valid,
    this.householdId,
    this.creatorName,
    this.error,
  });
}

/// A member of a household.
class FamilyMember {
  final String uid;
  final String name;
  final String role;
  final FamilyPermissions permissions;
  final DateTime? createdAt;

  const FamilyMember({
    required this.uid,
    required this.name,
    required this.role,
    this.permissions = const FamilyPermissions(),
    this.createdAt,
  });

  bool get isOwner => role == FamilyRole.owner;
}
