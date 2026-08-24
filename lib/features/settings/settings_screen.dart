import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import 'family_sync_screen.dart';

/// Simple settings: language, sound, voice, snooze/grace, appearance,
/// permissions and about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(l10n.setTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 16),

            _SectionHeader(l10n.familySync),
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 68,
              leading: Icon(
                Icons.family_restroom_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.familySync, style: theme.textTheme.titleMedium),
              subtitle: Text(
                l10n.familySyncDesc,
                style: theme.textTheme.bodyMedium,
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 30,
                color: theme.colorScheme.outline,
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FamilySyncScreen(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setLanguage),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'hi', label: Text('हिंदी')),
              ],
              selected: {settings.settings.locale},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(0, 60),
                textStyle: theme.textTheme.titleMedium,
              ),
              onSelectionChanged: (s) {
                settings.setLocale(s.first);
                appState.refresh(); // refresh notification text
              },
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setNotificationSound),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.setNotificationSound),
              subtitle: Text(l10n.setNotifDesc),
              value: settings.soundEnabled,
              onChanged: (v) async {
                await settings.setSoundEnabled(v);
                await appState.notifications.applySoundSetting(v);
                // Re-schedule pending notifications so they use the new
                // channel (sound on/off).
                await appState.notifications.cancelAllPending();
                await appState.refresh();
              },
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setVoiceReminder),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.setVoiceReminder),
              subtitle: Text(l10n.setVoiceOn),
              value: settings.voiceEnabled,
              onChanged: (v) async {
                await settings.setVoiceEnabled(v);
                if (v) {
                  final text = l10n.voiceTimeToTake('BP Tablet', '1 Tablet');
                  await appState.voice.speak(text, settings.settings.locale);
                } else {
                  await appState.voice.stop();
                }
              },
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setSnoozeDuration),
            _ChipSelector<int>(
              values: const [5, 10, 15, 20, 30],
              selected: settings.snoozeMinutes,
              labelOf: (v) => l10n.minutes(v),
              onSelected: settings.setSnoozeMinutes,
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setGracePeriod),
            _ChipSelector<int>(
              values: const [15, 30, 45, 60, 90, 120],
              selected: settings.graceMinutes,
              labelOf: (v) => l10n.minutes(v),
              onSelected: settings.setGraceMinutes,
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setDarkMode),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'system', label: Text(l10n.themeSystem)),
                ButtonSegment(value: 'light', label: Text(l10n.themeLight)),
                ButtonSegment(value: 'dark', label: Text(l10n.themeDark)),
              ],
              selected: {settings.settings.themeMode},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                minimumSize: const Size(0, 60),
                textStyle: theme.textTheme.titleMedium,
              ),
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setPermissions),
            _PermissionTile(
              icon: Icons.notifications_active_rounded,
              title: l10n.setNotifyPermission,
              subtitle: l10n.setNotifDesc,
              granted: appState.notificationsEnabled,
              grantedLabel: l10n.permissionGranted,
              deniedLabel: l10n.permissionDenied,
              onTap: () => appState.requestAllPermissions(),
            ),
            _PermissionTile(
              icon: Icons.alarm_add_rounded,
              title: l10n.setExactAlarm,
              subtitle: l10n.setExactDesc,
              granted: appState.exactAlarmsEnabled,
              grantedLabel: l10n.permissionGranted,
              deniedLabel: l10n.permissionDenied,
              onTap: () => appState.requestExactAlarms(),
            ),
            _PermissionTile(
              icon: Icons.battery_5_bar_rounded,
              title: l10n.setBattery,
              subtitle: l10n.setBatteryDesc,
              granted: true, // always shown; deep link to system settings
              grantedLabel: l10n.permOk,
              deniedLabel: '',
              onTap: () => AppSettings.openAppSettings(
                type: AppSettingsType.batteryOptimization,
              ),
            ),
            const SizedBox(height: 24),

            _SectionHeader(l10n.setAbout),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.appTitle} · v1.0.0',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.aboutBody, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChipSelector<T> extends StatelessWidget {
  const _ChipSelector({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ChoiceChip(
            label: Text(labelOf(v)),
            selected: v == selected,
            onSelected: (_) => onSelected(v),
          ),
      ],
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.grantedLabel,
    required this.deniedLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final String grantedLabel;
  final String deniedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = granted ? theme.successColor : theme.missedColor;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 68,
      leading: Icon(icon, size: 32, color: theme.colorScheme.primary),
      title: Text(title, style: theme.textTheme.titleMedium),
      subtitle: Text(subtitle, style: theme.textTheme.bodyMedium),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          granted ? grantedLabel : deniedLabel,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
