import 'package:app_settings/app_settings.dart' as app_settings;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../profile/profile_screen.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_status.dart';
import '../widgets/app_surfaces.dart';
import 'backup_screen.dart';
import 'family_sync_screen.dart';

Future<void> _openBatterySettings() => app_settings.AppSettings.openAppSettings(
  type: app_settings.AppSettingsType.batteryOptimization,
);

Future<void> _openExactAlarmSettings() =>
    app_settings.AppSettings.openAppSettings(
      type: app_settings.AppSettingsType.alarm,
    );

/// Settings, grouped the way a person thinks about them:
/// reminders → appearance → whether the phone will actually let us remind you →
/// account → your data → about.
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
    final allPermissionsOk =
        appState.notificationsEnabled &&
        appState.exactAlarmsEnabled &&
        appState.batteryUnrestricted;

    return AppPage(
      title: l10n.setTitle,
      children: [
        // ── Reminders ────────────────────────────────────────────────────
        AppSectionHeader(title: l10n.setGroupReminders),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              SwitchListTile(
                value: settings.soundEnabled,
                title: Text(l10n.setNotificationSound),
                subtitle: Text(l10n.setNotifDesc),
                onChanged: (v) async {
                  await settings.setSoundEnabled(v);
                  await appState.notifications.applySoundSetting(v);
                  await appState.notifications.cancelAllPending();
                  await appState.refresh();
                },
              ),
              const AppDivider(indent: AppSpacing.md),
              SwitchListTile(
                value: settings.voiceEnabled,
                title: Text(l10n.setVoiceReminder),
                subtitle: Text(l10n.setVoiceOn),
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
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),
        _ChoiceBlock<int>(
          label: l10n.setSnoozeDuration,
          values: const [5, 10, 15, 20, 30],
          selected: settings.snoozeMinutes,
          labelOf: (v) => l10n.minutes(v),
          onSelected: settings.setSnoozeMinutes,
        ),
        const SizedBox(height: AppSpacing.md),
        _ChoiceBlock<int>(
          label: l10n.setGracePeriod,
          values: const [15, 30, 45, 60, 90, 120],
          selected: settings.graceMinutes,
          labelOf: (v) => l10n.minutes(v),
          onSelected: settings.setGraceMinutes,
        ),
        const SizedBox(height: AppSpacing.md),
        _ChoiceBlock<int>(
          label: l10n.setAdvanceAlarm,
          helper: l10n.setAdvanceAlarmDesc,
          values: const [0, 1, 2, 3, 5, 10],
          selected: settings.advanceMinutes,
          labelOf: (v) => v == 0 ? l10n.off : l10n.minutes(v),
          onSelected: settings.setAdvanceMinutes,
        ),

        const SizedBox(height: AppSpacing.md),
        AppButton.secondary(
          label: l10n.testNotification,
          icon: Icons.volume_up_rounded,
          onPressed: () => _testNotification(appState, l10n),
        ),
        const SizedBox(height: AppSpacing.xs),
        // For a medicine app, "does a scheduled alarm actually fire on this
        // device?" is a safety question, so this stays available in release.
        AppButton.secondary(
          label: l10n.setTestScheduled,
          icon: Icons.timer_outlined,
          onPressed: () => _runSelfTest(appState, l10n),
        ),
        const SizedBox(height: AppSpacing.xs),
        FutureBuilder<Set<int>>(
          future: appState.notifications.pendingIds(),
          builder: (context, snap) => Text(
            l10n.setScheduledCount(snap.data?.length ?? 0),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        if (_selfTestInfo != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: SelectableText(
              _selfTestInfo!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            title: l10n.pauseAll,
            subtitle: Text(l10n.pauseAllConfirm),
            leading: AppIconBubble(
              icon: Icons.pause_circle_filled_rounded,
              color: theme.colorScheme.error,
              background: theme.colorScheme.errorContainer,
            ),
            onTap: () => _confirmPauseAll(appState, l10n),
          ),
        ),

        // ── Appearance ───────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: l10n.setDarkMode),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.setDarkMode, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'system',
                      label: Text(l10n.themeSystem),
                    ),
                    ButtonSegment(value: 'light', label: Text(l10n.themeLight)),
                    ButtonSegment(value: 'dark', label: Text(l10n.themeDark)),
                  ],
                  selected: {settings.settings.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.setLanguage, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'en', label: Text('English')),
                    ButtonSegment(value: 'hi', label: Text('हिंदी')),
                  ],
                  selected: {settings.settings.locale},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    settings.setLocale(s.first);
                    appState.refresh(); // refresh notification text
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Permissions ──────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(
          title: l10n.setPermissions,
          subtitle: allPermissionsOk
              ? l10n.notifStatusOk
              : l10n.notifStatusNeedsFix,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _PermissionRow(
                icon: Icons.notifications_active_rounded,
                title: l10n.setNotifyPermission,
                subtitle: l10n.setNotifDesc,
                granted: appState.notificationsEnabled,
                grantedLabel: l10n.permissionGranted,
                deniedLabel: l10n.permissionDenied,
                onTap: () => appState.requestAllPermissions(),
              ),
              const AppDivider(indent: AppSpacing.md),
              _PermissionRow(
                icon: Icons.alarm_add_rounded,
                title: l10n.setExactAlarm,
                subtitle: l10n.setExactDesc,
                granted: appState.exactAlarmsEnabled,
                grantedLabel: l10n.permissionGranted,
                deniedLabel: l10n.permissionDenied,
                onTap: () async {
                  // Go straight to the system "Alarms & reminders" screen — the
                  // plugin's in-app request is unreliable across OEMs.
                  await _openExactAlarmSettings();
                  await appState.refreshPermissionStatus();
                },
              ),
              const AppDivider(indent: AppSpacing.md),
              _PermissionRow(
                icon: Icons.battery_saver_rounded,
                title: l10n.setBattery,
                subtitle: l10n.setBatteryDesc,
                granted: appState.batteryUnrestricted,
                grantedLabel: l10n.permissionGranted,
                deniedLabel: l10n.setBatteryRestricted,
                onTap: _openBatterySettings,
              ),
            ],
          ),
        ),
        if (!appState.batteryUnrestricted) ...[
          const SizedBox(height: AppSpacing.sm),
          AppInfoNote(
            tone: AppNoteTone.warning,
            message: l10n.setBatteryWarning,
            actionLabel: l10n.setBattery,
            actionIcon: Icons.battery_alert_rounded,
            onAction: _openBatterySettings,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppButton.secondary(
          label: l10n.notifFixAll,
          icon: Icons.build_rounded,
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
        ),

        // ── Account ──────────────────────────────────────────────────────
        // Profile, family and deletion live behind Settings now that the bar
        // is Home · Medicines · History · Family.
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: l10n.profileAccount),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            title: l10n.profileTitle,
            subtitle: Text(l10n.profilePersonalInfo),
            leading: AppIconBubble(
              icon: Icons.person_rounded,
              color: theme.colorScheme.primary,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
            ),
          ),
        ),

        // ── Family & data ────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: l10n.familySync),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            title: l10n.familySync,
            subtitle: Text(l10n.familySyncDesc),
            leading: AppIconBubble(
              icon: Icons.family_restroom_rounded,
              color: theme.colorScheme.primary,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const FamilySyncScreen()),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: l10n.setData),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            title: l10n.setExportJson,
            subtitle: Text(l10n.setExportJsonDesc),
            leading: AppIconBubble(
              icon: Icons.backup_rounded,
              color: theme.colorScheme.tertiary,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const BackupScreen()),
            ),
          ),
        ),

        // ── About ────────────────────────────────────────────────────────
        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: l10n.setAbout),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.appTitle} · 1.0.1',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(l10n.aboutBody, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Future<void> _testNotification(
    AppState appState,
    AppLocalizations l10n,
  ) async {
    final notifs = appState.notifications;
    // Make sure permission is granted first, otherwise the OS silently drops
    // the notification and the user sees nothing.
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
    if (!mounted) return;
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

  Future<void> _runSelfTest(AppState appState, AppLocalizations l10n) async {
    final notifs = appState.notifications;
    if (!await notifs.areNotificationsEnabled()) {
      await notifs.requestPermission();
    }
    final r = await notifs.scheduleSelfTest(
      seconds: 60,
      title: '🔔 ${l10n.notifTitle}',
      body: l10n.setTestScheduledSent,
    );
    // Sync the on-screen permission badges to what scheduling actually found
    // (the cached flags can be stale/optimistic).
    await appState.refreshPermissionStatus();
    final t = TimeOfDay.fromDateTime(r.fireAt);
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final ss = r.fireAt.second.toString().padLeft(2, '0');
    if (mounted) {
      setState(() {
        _selfTestInfo = [
          'scheduled  : ${r.scheduled ? "yes" : "NO"}',
          'mode       : ${r.mode}'
              '${r.scheduled && !r.exact ? "  (inexact — Doze may delay / hold it)" : ""}',
          'in OS queue: ${r.verified ? "yes" : "NO — the OS did not keep it"}',
          'fires at   : $hh:$mm:$ss',
          'timezone   : ${r.tzName}',
        ].join('\n');
      });
    }
    if (!mounted) return;
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

  Future<void> _confirmPauseAll(
    AppState appState,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.pauseAll,
      message: l10n.pauseAllConfirm,
      confirmLabel: l10n.pauseAll,
      cancelLabel: l10n.btnCancel,
      icon: Icons.pause_circle_filled_rounded,
    );
    if (!confirmed) return;
    for (final med in appState.medicines.where((m) => m.active)) {
      await appState.setMedicineActive(med.id!, false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.pauseAll)));
  }
}

/// A titled row of single-choice chips (snooze, grace period, advance alarm).
class _ChoiceBlock<T> extends StatelessWidget {
  const _ChoiceBlock({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.helper,
  });

  final String label;
  final String? helper;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          if (helper != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(helper!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final v in values)
                ChoiceChip(
                  label: Text(labelOf(v)),
                  showCheckmark: false,
                  selected: v == selected,
                  onSelected: (_) => onSelected(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One permission with its current state written out in words.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
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
    return AppListRow(
      title: title,
      subtitle: Text(subtitle),
      leading: AppIconBubble(
        icon: icon,
        color: granted ? theme.palette.success : theme.palette.warning,
        background: granted
            ? theme.palette.successContainer
            : theme.palette.warningContainer,
      ),
      trailing: AppPill(
        label: granted ? grantedLabel : deniedLabel,
        icon: granted ? Icons.check_rounded : Icons.priority_high_rounded,
        color: granted ? theme.palette.success : theme.palette.warning,
        background: granted
            ? theme.palette.successContainer
            : theme.palette.warningContainer,
      ),
      onTap: onTap,
    );
  }
}
