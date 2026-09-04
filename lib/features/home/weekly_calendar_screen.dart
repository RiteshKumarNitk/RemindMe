import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';

/// Weekly calendar view showing all medicines at a glance.
/// Each day column shows medicines as colored dots/tiles.
class WeeklyCalendarScreen extends StatefulWidget {
  const WeeklyCalendarScreen({super.key});

  @override
  State<WeeklyCalendarScreen> createState() => _WeeklyCalendarScreenState();
}

class _WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = AppDateUtils.startOfWeek(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final settings = context.watch<SettingsController>();
    final now = DateTime.now();
    final locale = settings.settings.locale;
    final grace = settings.graceDuration;

    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.histThisWeek),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _weekStart = _weekStart.subtract(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          TextButton(
            onPressed: () => setState(() {
              _weekStart = AppDateUtils.startOfWeek(now);
            }),
            child: Text(l10n.histToday),
          ),
          IconButton(
            onPressed: () => setState(() {
              _weekStart = _weekStart.add(const Duration(days: 7));
            }),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<DoseEntry>>(
        future: appState
            .historyFor(_weekStart, _weekStart.add(const Duration(days: 7)))
            .then((r) => r.$1),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final allEntries = snapshot.data ?? [];

          // Group entries by day
          final dayMap = <DateTime, List<DoseEntry>>{};
          for (final day in days) {
            final dayKey = AppDateUtils.startOfDay(day);
            dayMap[dayKey] = allEntries
                .where(
                  (e) => AppDateUtils.startOfDay(e.dose.scheduledAt) == dayKey,
                )
                .toList()
              ..sort(
                (a, b) => a.dose.scheduledAt.compareTo(b.dose.scheduledAt),
              );
          }

          return Column(
            children: [
              // Day headers
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    for (final day in days) ...[
                      Expanded(
                        child: _DayHeader(
                          day: day,
                          isToday: AppDateUtils.sameDay(day, now),
                          locale: locale,
                        ),
                      ),
                      if (day != days.last) const SizedBox(width: 2),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),

              // Day columns with medicine tiles
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final day in days) ...[
                      Expanded(
                        child: _DayColumn(
                          day: day,
                          entries: dayMap[AppDateUtils.startOfDay(day)] ?? [],
                          isToday: AppDateUtils.sameDay(day, now),
                          grace: grace,
                          now: now,
                          l10n: l10n,
                        ),
                      ),
                      if (day != days.last)
                        Container(
                          width: 1,
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                    ],
                  ],
                ),
              ),

              // Legend
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendDot(color: theme.successColor, label: l10n.statusTaken),
                    const SizedBox(width: 16),
                    _LegendDot(color: theme.missedColor, label: l10n.statusMissed),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: theme.colorScheme.outline,
                      label: l10n.statusSkipped,
                    ),
                    const SizedBox(width: 16),
                    _LegendDot(
                      color: theme.pendingColor,
                      label: l10n.statusPending,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.isToday,
    required this.locale,
  });

  final DateTime day;
  final bool isToday;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          AppDateUtils.weekdayShort(day.weekday, locale),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isToday ? theme.colorScheme.primary : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${day.day}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isToday
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.day,
    required this.entries,
    required this.isToday,
    required this.grace,
    required this.now,
    required this.l10n,
  });

  final DateTime day;
  final List<DoseEntry> entries;
  final bool isToday;
  final Duration grace;
  final DateTime now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 12),
        child: Icon(
          Icons.check_circle_outline_rounded,
          size: 20,
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        children: [
          for (final entry in entries) ...[
            _MedicineChip(
              entry: entry,
              status: entry.effectiveStatus(grace, now),
              l10n: l10n,
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

class _MedicineChip extends StatelessWidget {
  const _MedicineChip({
    required this.entry,
    required this.status,
    required this.l10n,
  });

  final DoseEntry entry;
  final DoseStatus status;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (Color bgColor, Color textColor, IconData icon) = switch (status) {
      DoseStatus.taken => (
        theme.successColor.withValues(alpha: 0.15),
        theme.successColor,
        Icons.check_rounded,
      ),
      DoseStatus.missed => (
        theme.missedColor.withValues(alpha: 0.15),
        theme.missedColor,
        Icons.close_rounded,
      ),
      DoseStatus.skipped => (
        theme.colorScheme.surfaceContainerHighest,
        theme.colorScheme.onSurfaceVariant,
        Icons.remove_rounded,
      ),
      DoseStatus.pending => (
        theme.pendingColor.withValues(alpha: 0.15),
        theme.pendingColor,
        Icons.schedule_rounded,
      ),
    };

    // Show first 6 chars of medicine name for compact display
    final shortName = entry.medicine.name.length > 8
        ? '${entry.medicine.name.substring(0, 7)}…'
        : entry.medicine.name;

    return Tooltip(
      message:
          '${entry.medicine.name}\n${entry.medicine.doseLabel}\n${status.name}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: textColor),
            const SizedBox(height: 2),
            Text(
              shortName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
