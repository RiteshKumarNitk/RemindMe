import 'package:app_settings/app_settings.dart' as app_settings;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import 'backup_screen.dart';
import 'family_sync_screen.dart';

Future<void> _openBatterySettings() => app_settings.AppSettings.openAppSettings(
  type: app_settings.AppSettingsType.batteryOptimization,
);

Future<void> _openExactAlarmSettings() =>
    app_settings.AppSettings.openAppSettings(
      type: app_settings.AppSettingsType.alarm,
    );

/// Simple settings: language, sound, voice, snooze/grace, appearance,
/// permissions and about.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  /// Last "test a scheduled reminder" diagnostic, shown under the button.
  String? _selfTestInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The exact-alarm / notification / battery flags can be stale — re-check
    // them whenever this screen is shown or the app returns from OS settings.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AppState>().refreshPermissionStatus(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<AppState>().refreshPermissionStatus();
    }
  }

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

            _SectionHeader(l10n.setAdvanceAlarm),
            _ChipSelector<int>(
              values: const [0, 1, 2, 3, 5, 10],
              selected: settings.advanceMinutes,
              labelOf: (v) => v == 0 ? l10n.off : l10n.minutes(v),
              onSelected: settings.setAdvanceMinutes,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final notifs = appState.notifications;
                // Make sure permission is granted first, otherwise the OS
                // silently drops the notification and the user sees nothing.
                if (!await notifs.areNotificationsEnabled()) {
                  await notifs.requestPermission();
                }
                final granted = await notifs.areNotificationsEnabled();
                final shown =
                    granted &&
                    await notifs.showTestNotification(
                      title: '🔔 ${l10n.setNotificationSound}',
                      body: l10n.setNotifDesc,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        shown
                            ? l10n.testNotifSent
                            : !granted
                            ? l10n.permNotifBody
                            : l10n.testNotifFailed,
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.volume_up_rounded),
              label: Text(l10n.testNotification),
            ),
            // Developer-only scheduling self-test + raw diagnostic dump.
            // Hidden from release builds; users only see "Send a test
            // notification" above and the Notification status card below.
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final notifs = appState.notifications;
                  if (!await notifs.areNotificationsEnabled()) {
                    await notifs.requestPermission();
                  }
                  final r = await notifs.scheduleSelfTest(
                    seconds: 60,
                    title: '🔔 ${l10n.notifTitle}',
                    body: l10n.setTestScheduledSent,
                  );
                  // Sync the on-screen permission badges to what scheduling
                  // actually found (the cached flags can be stale/optimistic).
                  await appState.refreshPermissionStatus();
                  final t = TimeOfDay.fromDateTime(r.fireAt);
                  final hh = t.hour.toString().padLeft(2, '0');
                  final mm = t.minute.toString().padLeft(2, '0');
                  final ss = r.fireAt.second.toString().padLeft(2, '0');
                  if (mounted) {
                    setState(() {
                      _selfTestInfo = [
                        'scheduled : ${r.scheduled ? "yes" : "NO"}',
                        'mode      : ${r.mode}'
                            '${r.scheduled && !r.exact ? "  (inexact — Doze may delay / hold it)" : ""}',
                        'in OS queue: ${r.verified ? "yes" : "NO — the OS did not keep it"}',
                        'fires at  : $hh:$mm:$ss',
                        'timezone  : ${r.tzName}',
                      ].join('\n');
                    });
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 8),
                        content: Text(
                          !r.scheduled
                              ? l10n.setTestScheduledFailed
                              : r.exact
                              ? l10n.setTestScheduledSent
                              : l10n.setTestScheduledInexact,
                        ),
                        action: (r.scheduled && !r.exact)
                            ? SnackBarAction(
                                label: l10n.setPermissions,
                                onPressed: _openExactAlarmSettings,
                              )
                            : null,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.timer_outlined),
                label: Text(l10n.setTestScheduled),
              ),
              const SizedBox(height: 8),
              FutureBuilder<Set<int>>(
                future: appState.notifications.pendingIds(),
                builder: (context, snap) => Text(
                  l10n.setScheduledCount(snap.data?.length ?? 0),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_selfTestInfo != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    _selfTestInfo!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),

            _SectionHeader(l10n.pauseAll),
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                minTileHeight: 68,
                leading: Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 32,
                  color: theme.missedColor,
                ),
                title: Text(
                  l10n.pauseAll,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                subtitle: Text(
                  l10n.pauseAllConfirm,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
                trailing: Icon(
                  Icons.warning_rounded,
                  size: 28,
                  color: theme.missedColor,
                ),
                onTap: () => _confirmPauseAll(context, appState, l10n),
              ),
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

            if (!appState.batteryUnrestricted) ...[
              _WarningCard(
                text: l10n.setBatteryWarning,
                onTap: _openBatterySettings,
              ),
              const SizedBox(height: 8),
            ],

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
              onTap: () async {
                // Go straight to the system "Alarms & reminders" screen — the
                // plugin's in-app request is unreliable across OEMs. The user
                // toggles DoseWise on there; we re-check on resume.
                await _openExactAlarmSettings();
                await appState.refreshPermissionStatus();
              },
            ),
            _PermissionTile(
              icon: Icons.battery_saver_rounded,
              title: l10n.setBattery,
              subtitle: l10n.setBatteryDesc,
              granted: appState.batteryUnrestricted,
              grantedLabel: l10n.permissionGranted,
              deniedLabel: l10n.setBatteryRestricted,
              onTap: _openBatterySettings,
            ),

            const SizedBox(height: 12),
            // Diagnostic status + Fix All button
            Builder(
              builder: (context) {
                final allOk =
                    appState.notificationsEnabled &&
                    appState.exactAlarmsEnabled &&
                    appState.batteryUnrestricted;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              allOk
                                  ? Icons.check_circle_rounded
                                  : Icons.warning_rounded,
                              color: allOk
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                allOk
                                    ? l10n.notifStatusOk
                                    : l10n.notifStatusNeedsFix,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () async {
                              if (!appState.notificationsEnabled) {
                                await appState.requestAllPermissions();
                              }
                              if (!appState.exactAlarmsEnabled) {
                                await appState.requestExactAlarms();
                              }
                              if (!appState.batteryUnrestricted) {
                                await _openBatterySettings();
                              }
                            },
                            icon: const Icon(Icons.build_rounded),
                            label: Text(l10n.notifFixAll),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            _SectionHeader('Backup & Restore'),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                minTileHeight: 68,
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.backup_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: const Text('Backup & Restore'),
                subtitle: const Text('Save or restore your data'),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  );
                },
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

  void _confirmPauseAll(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.pauseAll),
        content: Text(l10n.pauseAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).missedColor,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.pauseAll),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      for (final med in appState.medicines.where((m) => m.active)) {
        await appState.setMedicineActive(med.id!, false);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.pauseAll)));
      }
    }
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

/// Prominent, tappable warning shown when the OS is battery-restricting the app.
class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                Icons.battery_alert_rounded,
                color: theme.colorScheme.onErrorContainer,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
            ],
          ),
        ),
      ),
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
        constraints: const BoxConstraints(maxWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          granted ? grantedLabel : deniedLabel,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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
