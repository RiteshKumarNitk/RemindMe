import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';

/// Holds the current [AppSettings] and persists changes. Notifies listeners
/// so the MaterialApp theme/locale rebuild.
class SettingsController extends ChangeNotifier {
  SettingsController(this._repository);

  final SettingsRepository _repository;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  bool get isHindi => _settings.locale == 'hi';
  bool get soundEnabled => _settings.soundEnabled;
  bool get voiceEnabled => _settings.voiceEnabled;
  int get snoozeMinutes => _settings.snoozeMinutes;
  int get graceMinutes => _settings.graceMinutes;
  Duration get snoozeDuration => _settings.snoozeDuration;
  Duration get graceDuration => _settings.graceDuration;
  bool get syncEnabled => _settings.syncEnabled;
  String get householdCode => _settings.householdCode;
  String get syncRole => _settings.syncRole;
  bool get missedAlertsEnabled => _settings.missedAlertsEnabled;
  DateTime? get lastSyncAt => _settings.lastSyncAt;
  String get userName => _settings.userName;
  bool get onboardingDone => _settings.onboardingDone;

  ThemeMode get themeMode {
    switch (_settings.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> load() async {
    _settings = _repository.load();
    notifyListeners();
  }

  Future<void> update(AppSettings settings) async {
    _settings = settings;
    Intl.defaultLocale = settings.locale;
    await _repository.save(settings);
    notifyListeners();
  }

  Future<void> setLocale(String locale) =>
      update(_settings.copyWith(locale: locale));
  Future<void> setSoundEnabled(bool value) =>
      update(_settings.copyWith(soundEnabled: value));
  Future<void> setVoiceEnabled(bool value) =>
      update(_settings.copyWith(voiceEnabled: value));
  Future<void> setSnoozeMinutes(int value) =>
      update(_settings.copyWith(snoozeMinutes: value));
  Future<void> setGraceMinutes(int value) =>
      update(_settings.copyWith(graceMinutes: value));
  Future<void> setThemeMode(String value) =>
      update(_settings.copyWith(themeMode: value));
  Future<void> setUserName(String value) =>
      update(_settings.copyWith(userName: value));
  Future<void> setOnboardingDone(bool value) =>
      update(_settings.copyWith(onboardingDone: value));

  Future<void> setSyncSettings({
    required bool syncEnabled,
    required String householdCode,
    required String syncRole,
    required DateTime? lastSyncAt,
  }) => update(
    _settings.copyWith(
      syncEnabled: syncEnabled,
      householdCode: householdCode,
      syncRole: syncRole,
      lastSyncAt: lastSyncAt,
    ),
  );

  Future<void> setMissedAlertsEnabled(bool value) =>
      update(_settings.copyWith(missedAlertsEnabled: value));

  Future<void> setLastSyncAt(DateTime value) =>
      update(_settings.copyWith(lastSyncAt: value));
}
