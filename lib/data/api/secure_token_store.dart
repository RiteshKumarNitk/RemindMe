import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

/// Keeps the healthcare-platform session in the OS keystore
/// (EncryptedSharedPreferences on Android) rather than plain preferences —
/// a refresh token is a long-lived credential and should never sit in
/// cleartext.
///
/// Falls back to an in-memory store if the keystore is unavailable, so a
/// broken keystore degrades to "you must sign in again next launch" instead
/// of a crash.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'platform_session_v1';

  final FlutterSecureStorage _storage;
  final InMemoryTokenStore _fallback = InMemoryTokenStore();
  bool _usingFallback = false;

  @override
  Future<PlatformTokens?> read() async {
    if (_usingFallback) return _fallback.read();
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return PlatformTokens.fromJson(jsonDecode(raw));
    } catch (e) {
      developer.log(
        'Secure storage read failed — falling back to memory',
        name: 'PlatformAuth',
        error: e,
      );
      _usingFallback = true;
      return _fallback.read();
    }
  }

  @override
  Future<void> write(PlatformTokens tokens) async {
    if (_usingFallback) return _fallback.write(tokens);
    try {
      await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
    } catch (e) {
      developer.log(
        'Secure storage write failed — falling back to memory',
        name: 'PlatformAuth',
        error: e,
      );
      _usingFallback = true;
      await _fallback.write(tokens);
    }
  }

  @override
  Future<void> clear() async {
    await _fallback.clear();
    if (_usingFallback) return;
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      developer.log(
        'Secure storage clear failed',
        name: 'PlatformAuth',
        error: e,
      );
    }
  }
}
