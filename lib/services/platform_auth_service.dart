import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../data/api/api_client.dart';
import '../data/api/api_exception.dart';
import '../data/api/token_store.dart';
import '../data/models/healthcare/appointment.dart';

enum PlatformAuthStatus {
  /// Still checking whether a stored session is usable.
  restoring,
  signedOut,
  signedIn,
}

/// The DoseWise app's account on the healthcare platform.
///
/// Deliberately separate from [AuthService] (Firebase, which powers the
/// family-sync features): booking lives in the platform's own user table, so
/// it needs a platform session. The medicine-reminder product keeps working
/// exactly as before whether or not this session exists.
///
/// The mobile client identifies itself with `X-Client: app`, which makes the
/// API answer with bearer tokens instead of a web session cookie.
class PlatformAuthService extends ChangeNotifier {
  PlatformAuthService({required ApiClient client}) : _client = client;

  final ApiClient _client;

  PlatformAuthStatus _status = PlatformAuthStatus.restoring;
  PlatformUser? _user;
  ApiException? _lastError;

  PlatformAuthStatus get status => _status;
  PlatformUser? get user => _user;
  ApiException? get lastError => _lastError;
  bool get isSignedIn => _status == PlatformAuthStatus.signedIn;
  bool get isRestoring => _status == PlatformAuthStatus.restoring;

  /// Restores a stored session (if any) and loads the profile.
  Future<void> restore() async {
    final tokens = await _client.tokenStore.read();
    if (tokens == null) {
      _status = PlatformAuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      _user = await _loadMe();
      _status = PlatformAuthStatus.signedIn;
    } on ApiException catch (e) {
      if (e.isUnauthenticated || e.sessionExpired) {
        await _client.tokenStore.clear();
        _status = PlatformAuthStatus.signedOut;
      } else {
        // Network trouble: keep the session and let the UI retry.
        _lastError = e;
        _status = PlatformAuthStatus.signedIn;
      }
    } catch (e) {
      developer.log('Session restore failed', name: 'PlatformAuth', error: e);
      _status = PlatformAuthStatus.signedOut;
    }
    notifyListeners();
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _authenticate(
      () => _client.post(
        '/auth/login',
        auth: AuthMode.none,
        body: {'email': email.trim(), 'password': password},
      ),
    );
  }

  /// Creates a platform account, then signs in (the register endpoint only
  /// returns an id, so a login is always required to obtain tokens).
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      _lastError = null;
      await _client.post(
        '/auth/register',
        auth: AuthMode.none,
        body: {
          'fullName': fullName.trim(),
          'email': email.trim(),
          'password': password,
        },
      );
    } on ApiException catch (e) {
      _lastError = e;
      notifyListeners();
      return false;
    }
    return signIn(email: email, password: password);
  }

  Future<bool> _authenticate(Future<JsonMap> Function() request) async {
    _lastError = null;
    try {
      final json = await request();
      final tokens = PlatformTokens.fromJson(json);
      if (tokens == null) {
        _lastError = ApiException.malformedResponse(200);
        notifyListeners();
        return false;
      }
      await _client.tokenStore.write(tokens);
      _user = await _loadMe();
      _status = PlatformAuthStatus.signedIn;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastError = e;
      await _client.tokenStore.clear();
      _status = PlatformAuthStatus.signedOut;
      notifyListeners();
      return false;
    }
  }

  Future<PlatformUser> _loadMe() async {
    final json = await _client.getObject('/me', auth: AuthMode.required);
    return PlatformUser.fromJson(json);
  }

  /// Re-reads the profile (after a rename, or when a screen needs it fresh).
  Future<void> refreshProfile() async {
    if (!isSignedIn) return;
    try {
      _user = await _loadMe();
      notifyListeners();
    } on ApiException catch (e) {
      _lastError = e;
      if (e.isUnauthenticated || e.sessionExpired) {
        await signOut();
      } else {
        notifyListeners();
      }
    }
  }

  Future<void> signOut() async {
    await _client.revokeSession();
    await _client.tokenStore.clear();
    _user = null;
    _status = PlatformAuthStatus.signedOut;
    _lastError = null;
    notifyListeners();
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }
}
