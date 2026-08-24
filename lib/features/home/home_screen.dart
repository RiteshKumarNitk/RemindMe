import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/big_button.dart';
import '../widgets/permission_banner.dart';
import '../widgets/status_view.dart';

/// The dashboard. Answers "which medicine do I need to take now?" at a glance.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onAddMedicine});

  final VoidCallback onAddMedicine;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final locale = settings.settings.locale;

    final greeting = switch (now.hour) {
      < 12 => l10n.greetingMorning,
      < 17 => l10n.greetingAfternoon,
      _ => l10n.greetingEvening,
    };
    final name = settings.userName.trim();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            name.isEmpty ? '$greeting ❤️' : '$greeting, $name ❤️',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          PermissionBanner(
            show: !appState.notificationsEnabled,
            title: l10n.setNotifyPermission,
            subtitle: l10n.setNotifDesc,
            buttonLabel: l10n.permOk,
            onPressed: () => appState.requestAllPermissions(),
          ),
          const SizedBox(height: 10),
          PermissionBanner(
            show: !appState.exactAlarmsEnabled,
            title: l10n.setExactAlarm,
            subtitle: l10n.setExactDesc,
            buttonLabel: l10n.permOk,
            icon: Icons.alarm_add_rounded,
            onPressed: () => appState.requestExactAlarms(),
          ),
          const SizedBox(height: 12),
          if (appState.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (appState.nextDose != null)
              _NextMedicineCard(entry: appState.nextDose!)
            else
              _AllDoneCard(l10n: l10n),
            const SizedBox(height: 20),
            _StatsRow(stats: appState.todayStats, l10n: l10n),
            const SizedBox(height: 20),
            _DailyProgressBar(stats: appState.todayStats, l10n: l10n),
            const SizedBox(height: 24),
            Text(l10n.homeTodayMedicines, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            if (appState.todayDoses.isEmpty)
              _EmptyToday(
                l10n: l10n,
                hasMedicines: appState.medicines.isNotEmpty,
                onAddMedicine: onAddMedicine,
              )
            else
              for (final entry in appState.todayDoses)
                _TodayDoseTile(
                  entry: entry,
                  locale: locale,
                  grace: settings.graceDuration,
                ),
          ],
        ],
      ),
    );
  }
}

class _NextMedicineCard extends StatefulWidget {
  const _NextMedicineCard({required this.entry});

  final DoseEntry entry;

  @override
  State<_NextMedicineCard> createState() => _NextMedicineCardState();
}

class _NextMedicineCardState extends State<_NextMedicineCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final appState = context.read<AppState>();
    final settings = context.read<SettingsController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = settings.settings.locale;
    final now = DateTime.now();
    final scheduled = entry.dose.scheduledAt;
    final isDueNow = !scheduled.isAfter(now.add(const Duration(minutes: 10)));
    final countdown = _countdownText(scheduled, now, l10n);

    return Card(
      color: isDueNow
          ? theme.colorScheme.errorContainer
          : theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.homeNextMedicine.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isDueNow
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (countdown != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDueNow
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      countdown,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ScaleTransition(
                  scale: isDueNow
                      ? CurvedAnimation(
                          parent: _pulseController,
                          curve: Curves.easeInOut,
                        )
                      : const AlwaysStoppedAnimation(1.0),
                  child: Icon(
                    isDueNow
                        ? Icons.notifications_active_rounded
                        : Icons.medication_rounded,
                    size: 46,
                    color: isDueNow
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.medicine.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: isDueNow
                          ? theme.colorScheme.onErrorContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.speakReminder,
                  iconSize: 34,
                  onPressed: () => _speak(context, entry, l10n, settings),
                  icon: Icon(
                    Icons.volume_up_rounded,
                    color: isDueNow
                        ? theme.colorScheme.onErrorContainer
                        : theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            if (entry.medicine.doseLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.medicine.doseLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isDueNow
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
              style: theme.textTheme.titleLarge?.copyWith(
                color: isDueNow
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            BigButton(
              label: l10n.homeTakeMedicine,
              icon: Icons.check_rounded,
              onPressed: () async {
                await appState.markTaken(entry);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.undoTaken),
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: l10n.undo,
                        onPressed: () => appState.undoLastAction(),
                      ),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 4),
            BigTextButton(
              label: l10n.homeSkip,
              onPressed: () => _confirmSkip(context, appState, entry, l10n),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSkip(
    BuildContext context,
    AppState appState,
    DoseEntry entry,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.homeSkipConfirmTitle),
        content: Text(l10n.homeSkipConfirmBody(entry.medicine.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.homeSkip),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.markSkipped(entry);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.undoSkipped),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: l10n.undo,
              onPressed: () => appState.undoLastAction(),
            ),
          ),
        );
      }
    }
  }

  String? _countdownText(
    DateTime scheduled,
    DateTime now,
    AppLocalizations l10n,
  ) {
    final diff = scheduled.difference(now);
    if (diff.isNegative) {
      final over = now.difference(scheduled);
      if (over.inMinutes < 60) return l10n.homeOverdueMin(over.inMinutes);
      return l10n.homeOverdueHours(over.inHours);
    }
    if (diff.inMinutes < 60) return l10n.homeInMin(diff.inMinutes);
    if (diff.inHours < 24) return l10n.homeInHours(diff.inHours);
    return l10n.homeInDays(diff.inDays);
  }

  void _speak(
    BuildContext context,
    DoseEntry entry,
    AppLocalizations l10n,
    SettingsController s,
  ) {
    final voice = context.read<AppState>().voice;
    final text = l10n.voiceTimeToTake(
      entry.medicine.name,
      entry.medicine.doseLabel,
    );
    voice.speak(text, s.settings.locale);
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.celebration_rounded,
              size: 44,
              color: theme.successColor,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l10n.homeNoMoreToday,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.l10n});

  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        _StatCard(
          icon: Icons.check_circle_rounded,
          color: theme.successColor,
          value: stats.taken,
          label: l10n.homeTaken,
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.alarm_rounded,
          color: theme.pendingColor,
          value: stats.pending,
          label: l10n.homeRemaining,
        ),
        const SizedBox(width: 10),
        _StatCard(
          icon: Icons.cancel_rounded,
          color: theme.missedColor,
          value: stats.missed,
          label: l10n.homeMissed,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 6),
              Text(
                '$value',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A linear progress bar showing daily dose completion at a glance.
class _DailyProgressBar extends StatelessWidget {
  const _DailyProgressBar({required this.stats, required this.l10n});

  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats.total;
    if (total == 0) return const SizedBox.shrink();
    final done = stats.taken + stats.skipped;
    final progress = done / total;
    final label = '$done / $total ${l10n.homeDosesDone}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stacked_bar_chart_rounded,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 12,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: progress >= 1.0
                    ? theme.successColor
                    : theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({
    required this.l10n,
    required this.hasMedicines,
    required this.onAddMedicine,
  });

  final AppLocalizations l10n;
  final bool hasMedicines;
  final VoidCallback onAddMedicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(
            hasMedicines ? l10n.homeEmptySchedule : l10n.homeNoMedicines,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          if (!hasMedicines)
            BigButton(
              label: l10n.medAdd,
              icon: Icons.add_rounded,
              onPressed: onAddMedicine,
            ),
        ],
      ),
    );
  }
}

class _TodayDoseTile extends StatelessWidget {
  const _TodayDoseTile({
    required this.entry,
    required this.locale,
    required this.grace,
  });

  final DoseEntry entry;
  final String locale;
  final Duration grace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final status = entry.effectiveStatus(grace, now);
    final (icon, color) = statusVisual(theme, status);

    final statusLabel = switch (status) {
      DoseStatus.taken => l10n.statusTaken,
      DoseStatus.skipped => l10n.statusSkipped,
      DoseStatus.missed => l10n.statusMissed,
      DoseStatus.pending => l10n.statusPending,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 88,
              child: Text(
                AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(icon, size: 30, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.medicine.name, style: theme.textTheme.titleMedium),
                  if (entry.medicine.doseLabel.isNotEmpty)
                    Text(
                      entry.medicine.doseLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(status: status, label: statusLabel),
          ],
        ),
      ),
    );
  }
}
