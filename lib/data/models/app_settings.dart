/// User-adjustable application settings.
class AppSettings {
  final String locale; // 'en' | 'hi'
  final bool soundEnabled;
  final bool voiceEnabled;
  final int snoozeMinutes;
  final int graceMinutes;
  final int advanceMinutes; // minutes before dose to start looping alarm
  final String themeMode; // 'system' | 'light' | 'dark'
  final String userName;
  final bool onboardingDone;

  // Family sync
  final bool syncEnabled;
  final String householdCode;
  final String syncRole; // 'primary' | 'watcher'
  final bool missedAlertsEnabled;
  final DateTime? lastSyncAt;

  const AppSettings({
    this.locale = 'en',
    this.soundEnabled = true,
    this.voiceEnabled = true,
    this.snoozeMinutes = 10,
    this.graceMinutes = 30,
    this.advanceMinutes = 5,
    this.themeMode = 'system',
    this.userName = '',
    this.onboardingDone = false,
    this.syncEnabled = false,
    this.householdCode = '',
    this.syncRole = 'primary',
    this.missedAlertsEnabled = true,
    this.lastSyncAt,
  });

  Duration get snoozeDuration => Duration(minutes: snoozeMinutes);
  Duration get graceDuration => Duration(minutes: graceMinutes);

  AppSettings copyWith({
    String? locale,
    bool? soundEnabled,
    bool? voiceEnabled,
    int? snoozeMinutes,
    int? graceMinutes,
    int? advanceMinutes,
    String? themeMode,
    String? userName,
    bool? onboardingDone,
    bool? syncEnabled,
    String? householdCode,
    String? syncRole,
    bool? missedAlertsEnabled,
    DateTime? lastSyncAt,
  }) {
    return AppSettings(
      locale: locale ?? this.locale,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      advanceMinutes: advanceMinutes ?? this.advanceMinutes,
      themeMode: themeMode ?? this.themeMode,
      userName: userName ?? this.userName,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      syncEnabled: syncEnabled ?? this.syncEnabled,
      householdCode: householdCode ?? this.householdCode,
      syncRole: syncRole ?? this.syncRole,
      missedAlertsEnabled: missedAlertsEnabled ?? this.missedAlertsEnabled,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }
}
