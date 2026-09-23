import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the healthcare platform (Next.js + PostgreSQL) lives.
///
/// DoseWise's medicine reminders stay fully on-device; only the healthcare
/// discovery/booking feature talks to this host. There is **one** source of
/// truth for clinics, doctors and appointments: the platform's database,
/// reached through its REST API — never a local copy in the app.
///
/// The value is baked at build time with
/// `--dart-define=PLATFORM_API_BASE_URL=https://<host>/api`. The compiled
/// default points at a Next.js dev server running on the developer's machine
/// as seen from the Android emulator (`10.0.2.2` = host loopback). Debug
/// builds can override it at runtime from the healthcare screen's overflow
/// menu so a physical device can be pointed at a LAN or preview deployment
/// without a rebuild.
class PlatformApiConfig {
  PlatformApiConfig._();

  static const String _overrideKey = 'platform_api_base_url_override';

  /// Compile-time base URL, e.g. `http://10.0.2.2:3000/api`.
  static const String compiledBaseUrl = String.fromEnvironment(
    'PLATFORM_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api',
  );

  static String? _override;
  static bool _loaded = false;

  /// Effective base URL (no trailing slash).
  static String get baseUrl => _normalize(_override ?? compiledBaseUrl);

  /// True when a runtime override is in effect.
  static bool get hasOverride => _override != null && _override!.isNotEmpty;

  /// A runtime override only makes sense for QA builds — release builds ship
  /// against whatever was compiled in.
  static bool get overrideAllowed => kDebugMode;

  /// Reads any previously saved override. Safe to call more than once.
  static Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_overrideKey);
      if (saved != null && saved.trim().isNotEmpty) {
        _override = _normalize(saved);
      }
    } catch (_) {
      // Prefs unavailable — fall back to the compiled value.
    }
  }

  /// Sets (or clears, with `null`/empty) the runtime override.
  static Future<void> setOverride(String? url) async {
    final normalized = url == null || url.trim().isEmpty
        ? null
        : _normalize(url);
    _override = normalized;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (normalized == null) {
        await prefs.remove(_overrideKey);
      } else {
        await prefs.setString(_overrideKey, normalized);
      }
    } catch (_) {
      // Keep the in-memory value even if persisting failed.
    }
  }

  static String _normalize(String value) {
    var v = value.trim();
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }
}
