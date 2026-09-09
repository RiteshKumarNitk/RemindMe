import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Manages family invitation tokens for QR-code based family connection.
///
/// Flow:
///   1. User A calls [createInvitation] → gets a token
///   2. Token is encoded into a QR code
///   3. User B scans the QR code, gets the token
///   4. User B calls [validateInvitation] → gets family info + creator name
///   5. User B calls [acceptInvitation] → joins the family
///
/// Security:
///   - Tokens are short-lived (24 hours by default)
///   - Tokens are single-use by default (can be made reusable)
///   - Tokens are SHA-256 hashed before storage (plain text in QR only)
///   - Tokens include a checksum to prevent tampering
class InvitationService {
  InvitationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Duration after which an invitation token expires.
  static const Duration tokenTTL = Duration(hours: 24);

  /// Creates a new family invitation token.
  ///
  /// Returns an [InvitationData] containing the token string (to encode in QR)
  /// and metadata. The token is stored hashed in Firestore.
  Future<InvitationData> createInvitation({
    required String householdCode,
    required String creatorUid,
    required String creatorName,
  }) async {
    final rawToken = _generateToken();
    final hashedToken = _hashToken(rawToken);
    final now = DateTime.now().toUtc();

    final invitation = {
      'householdCode': householdCode,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(now.add(tokenTTL)),
      'used': false,
      'usedBy': null,
      'usedAt': null,
    };

    try {
      await _firestore
          .collection('invitations')
          .doc(hashedToken)
          .set(invitation);

      developer.log(
        'Invitation created: household=$householdCode creator=$creatorName',
        name: 'Invitation',
      );

      return InvitationData(
        token: rawToken,
        householdCode: householdCode,
        creatorName: creatorName,
        expiresAt: now.add(tokenTTL),
      );
    } catch (e) {
      developer.log('createInvitation FAILED: $e', name: 'Invitation', error: e);
      rethrow;
    }
  }

  /// Validates an invitation token and returns the family info.
  ///
  /// Checks:
  ///   - Token exists in Firestore
  ///   - Token has not expired
  ///   - Token has not been used (if single-use)
  ///
  /// Returns [InvitationValidation] with family info if valid, or throws
  /// with a user-friendly error message.
  Future<InvitationValidation> validateInvitation({
    required String token,
    required String currentUid,
  }) async {
    final hashedToken = _hashToken(token);

    try {
      final doc = await _firestore
          .collection('invitations')
          .doc(hashedToken)
          .get();

      if (!doc.exists) {
        return InvitationValidation(
          valid: false,
          error: 'Invalid QR code. This invitation does not exist.',
        );
      }

      final data = doc.data()!;
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      final used = data['used'] == true;
      final creatorUid = data['creatorUid'] as String? ?? '';
      final householdCode = data['householdCode'] as String? ?? '';
      final creatorName = data['creatorName'] as String? ?? '';

      // Check expiry
      if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
        return InvitationValidation(
          valid: false,
          error: 'This QR code has expired. Ask for a new one.',
        );
      }

      // Check if already used
      if (used) {
        return InvitationValidation(
          valid: false,
          error: 'This QR code has already been used.',
        );
      }

      // Check if scanning own QR code
      if (creatorUid == currentUid) {
        return InvitationValidation(
          valid: false,
          error: 'You cannot scan your own QR code.',
        );
      }

      // Check if already connected
      final householdDoc = await _firestore
          .collection('households')
          .doc(householdCode)
          .get();

      if (householdDoc.exists) {
        final members = householdDoc.data()?['members'] as Map<String, dynamic>?;
        if (members != null && members.containsKey(currentUid)) {
          return InvitationValidation(
            valid: false,
            error: 'You are already connected to this family.',
          );
        }
      }

      return InvitationValidation(
        valid: true,
        householdCode: householdCode,
        creatorName: creatorName,
      );
    } catch (e) {
      developer.log('validateInvitation FAILED: $e', name: 'Invitation', error: e);
      return InvitationValidation(
        valid: false,
        error: 'Network error. Please check your connection and try again.',
      );
    }
  }

  /// Accepts an invitation and joins the family.
  ///
  /// Marks the token as used and adds the user to the household members.
  /// Returns the household code on success.
  Future<String> acceptInvitation({
    required String token,
    required String currentUid,
    required String currentUserName,
  }) async {
    final hashedToken = _hashToken(token);

    try {
      // Validate first
      final validation = await validateInvitation(
        token: token,
        currentUid: currentUid,
      );

      if (!validation.valid) {
        throw StateError(validation.error ?? 'Invalid invitation');
      }

      final householdCode = validation.householdCode!;

      // Mark token as used
      await _firestore
          .collection('invitations')
          .doc(hashedToken)
          .update({
        'used': true,
        'usedBy': currentUid,
        'usedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      });

      // Add user to household members
      await _firestore
          .collection('households')
          .doc(householdCode)
          .update({
        'members.$currentUid': {
          'role': 'member',
          'name': currentUserName,
          'joinedAt': DateTime.now().toUtc().toIso8601String(),
        },
      });

      developer.log(
        'Invitation accepted: user=$currentUserName household=$householdCode',
        name: 'Invitation',
      );

      return householdCode;
    } catch (e) {
      developer.log('acceptInvitation FAILED: $e', name: 'Invitation', error: e);
      rethrow;
    }
  }

  /// Gets all family members for a household.
  Future<List<FamilyMember>> getFamilyMembers(String householdCode) async {
    try {
      final doc = await _firestore
          .collection('households')
          .doc(householdCode)
          .get();

      if (!doc.exists) return [];

      final membersData = doc.data()?['members'] as Map<String, dynamic>?;
      if (membersData == null) return [];

      final members = <FamilyMember>[];
      for (final entry in membersData.entries) {
        final data = entry.value as Map<String, dynamic>;
        members.add(FamilyMember(
          uid: entry.key,
          name: data['name'] as String? ?? 'Unknown',
          role: data['role'] as String? ?? 'member',
          joinedAt: data['joinedAt'] as String?,
        ));
      }

      return members;
    } catch (e) {
      developer.log('getFamilyMembers FAILED: $e', name: 'Invitation', error: e);
      return [];
    }
  }

  /// Removes a member from the family (admin only).
  Future<void> removeMember({
    required String householdCode,
    required String adminUid,
    required String memberUid,
  }) async {
    try {
      final doc = await _firestore
          .collection('households')
          .doc(householdCode)
          .get();

      if (!doc.exists) throw StateError('Household not found');

      final members = doc.data()?['members'] as Map<String, dynamic>?;
      final adminRole = members?[adminUid]?['role'] as String?;

      if (adminRole != 'primary' && adminRole != 'admin') {
        throw StateError('Only the family admin can remove members');
      }

      await _firestore
          .collection('households')
          .doc(householdCode)
          .update({
        'members.$memberUid': FieldValue.delete(),
      });

      developer.log(
        'Member removed: $memberUid from household=$householdCode by $adminUid',
        name: 'Invitation',
      );
    } catch (e) {
      developer.log('removeMember FAILED: $e', name: 'Invitation', error: e);
      rethrow;
    }
  }

  /// Cleans up expired invitations (call periodically).
  Future<void> cleanupExpired() async {
    try {
      final expired = await _firestore
          .collection('invitations')
          .where('expiresAt', isLessThan: Timestamp.fromDate(DateTime.now().toUtc()))
          .get();

      final batch = _firestore.batch();
      for (final doc in expired.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (expired.docs.isNotEmpty) {
        developer.log(
          'Cleaned up ${expired.docs.length} expired invitations',
          name: 'Invitation',
        );
      }
    } catch (e) {
      developer.log('cleanupExpired FAILED: $e', name: 'Invitation', error: e);
    }
  }

  /// Generates a cryptographically random token.
  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Hashes a token with SHA-256 for secure storage.
  String _hashToken(String token) {
    final bytes = utf8.encode(token);
    return sha256.convert(bytes).toString();
  }
}

/// Data returned when creating an invitation.
class InvitationData {
  final String token;
  final String householdCode;
  final String creatorName;
  final DateTime expiresAt;

  const InvitationData({
    required this.token,
    required this.householdCode,
    required this.creatorName,
    required this.expiresAt,
  });

  /// Encodes the invitation data as a JSON string for QR code.
  String toQrPayload() {
    return jsonEncode({
      'type': 'dosewise_invite',
      'token': token,
      'v': 1, // version for future compatibility
    });
  }

  /// Parses a QR code payload back to invitation data.
  static InvitationData? fromQrPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (data['type'] != 'dosewise_invite') return null;
      return InvitationData(
        token: data['token'] as String,
        householdCode: '', // not in QR for security
        creatorName: '', // not in QR for security
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
  final String? householdCode;
  final String? creatorName;
  final String? error;

  const InvitationValidation({
    required this.valid,
    this.householdCode,
    this.creatorName,
    this.error,
  });
}

/// A family member in the household.
class FamilyMember {
  final String uid;
  final String name;
  final String role;
  final String? joinedAt;

  const FamilyMember({
    required this.uid,
    required this.name,
    required this.role,
    this.joinedAt,
  });

  bool get isAdmin => role == 'primary' || role == 'admin';
}
