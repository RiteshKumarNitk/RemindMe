import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Persists [AppSettings] using SharedPreferences.
class SettingsRepository {
  SettingsRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _kLocale = 'locale';
  static const _kSound = 'sound_enabled';
  static const _kVoice = 'voice_enabled';
  static const _kSnooze = 'snooze_minutes';
  static const _kGrace = 'grace_minutes';
  static const _kTheme = 'theme_mode';
  static const _kUserName = 'user_name';
  static const _kOnboarding = 'onboarding_done';
  static const _kSyncEnabled = 'sync_enabled';
  static const _kHousehold = 'household_code';
  static const _kSyncRole = 'sync_role';
  static const _kMissedAlerts = 'missed_alerts_enabled';
  static const _kLastSyncAt = 'last_sync_at';

  AppSettings load() {
    return AppSettings(
      locale: _prefs.getString(_kLocale) ?? 'en',
      soundEnabled: _prefs.getBool(_kSound) ?? true,
      voiceEnabled: _prefs.getBool(_kVoice) ?? false,
      snoozeMinutes: _prefs.getInt(_kSnooze) ?? 10,
      graceMinutes: _prefs.getInt(_kGrace) ?? 30,
      themeMode: _prefs.getString(_kTheme) ?? 'system',
      userName: _prefs.getString(_kUserName) ?? '',
      onboardingDone: _prefs.getBool(_kOnboarding) ?? false,
      syncEnabled: _prefs.getBool(_kSyncEnabled) ?? false,
      householdCode: _prefs.getString(_kHousehold) ?? '',
      syncRole: _prefs.getString(_kSyncRole) ?? 'primary',
      missedAlertsEnabled: _prefs.getBool(_kMissedAlerts) ?? true,
      lastSyncAt: _prefs.getString(_kLastSyncAt) == null
          ? null
          : DateTime.tryParse(_prefs.getString(_kLastSyncAt)!),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_kLocale, settings.locale);
    await _prefs.setBool(_kSound, settings.soundEnabled);
    await _prefs.setBool(_kVoice, settings.voiceEnabled);
    await _prefs.setInt(_kSnooze, settings.snoozeMinutes);
    await _prefs.setInt(_kGrace, settings.graceMinutes);
    await _prefs.setString(_kTheme, settings.themeMode);
    await _prefs.setString(_kUserName, settings.userName);
    await _prefs.setBool(_kOnboarding, settings.onboardingDone);
    await _prefs.setBool(_kSyncEnabled, settings.syncEnabled);
    await _prefs.setString(_kHousehold, settings.householdCode);
    await _prefs.setString(_kSyncRole, settings.syncRole);
    await _prefs.setBool(_kMissedAlerts, settings.missedAlertsEnabled);
    if (settings.lastSyncAt == null) {
      await _prefs.remove(_kLastSyncAt);
    } else {
      await _prefs.setString(
        _kLastSyncAt,
        settings.lastSyncAt!.toIso8601String(),
      );
    }
  }
}
