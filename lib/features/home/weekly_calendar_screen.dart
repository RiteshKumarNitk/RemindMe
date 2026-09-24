import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/app_states.dart';
import '../widgets/app_status.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/dose_list_tile.dart';

/// A week at a glance — without shrinking the text to fit seven columns.
///
/// The strip across the top carries the day, the date and a row of status dots
/// (a second, non-textual cue); the day you pick is listed underneath at normal
/// reading size. This is the whole reason a 7-column grid of 9pt labels was
/// replaced: on a phone it was unreadable, which for this app means unusable.
class WeeklyCalendarScreen extends StatefulWidget {
  const WeeklyCalendarScreen({super.key});

  @override
  State<WeeklyCalendarScreen> createState() => _WeeklyCalendarScreenState();
}

class _WeeklyCalendarScreenState extends State<WeeklyCalendarScreen> {
  late DateTime _weekStart;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _weekStart = AppDateUtils.startOfWeek(DateTime.now());
    _selectedDay = AppDateUtils.startOfDay(DateTime.now());
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
              _selectedDay = _weekStart;
            }),
            tooltip: l10n.histThisWeek,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          TextButton(
            onPressed: () => setState(() {
              _weekStart = AppDateUtils.startOfWeek(now);
              _selectedDay = AppDateUtils.startOfDay(now);
            }),
            child: Text(l10n.histToday),
          ),
          IconButton(
            onPressed: () => setState(() {
              _weekStart = _weekStart.add(const Duration(days: 7));
              _selectedDay = _weekStart;
            }),
            tooltip: l10n.histAll,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      body: FutureBuilder<(List<DoseEntry>, AdherenceStats)>(
        future: appState.historyFor(_weekStart, _weekStart.add(const Duration(days: 7))),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SkeletonList(rows: 4);
          }
          final allEntries = snapshot.data?.$1 ?? const <DoseEntry>[];

          final dayMap = <DateTime, List<DoseEntry>>{};
          for (final day in days) {
            final key = AppDateUtils.startOfDay(day);
            dayMap[key] = allEntries
                .where((e) => AppDateUtils.startOfDay(e.dose.scheduledAt) == key)
                .toList()
              ..sort((a, b) => a.dose.scheduledAt.compareTo(b.dose.scheduledAt));
          }

          final selected = _selectedDay ?? AppDateUtils.startOfDay(now);
          final selectedEntries = dayMap[selected] ?? const <DoseEntry>[];

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              // ── Week strip ─────────────────────────────────────────────
              Row(
                children: [
                  for (final day in days) ...[
                    Expanded(
                      child: _DayTile(
                        day: day,
                        entries: dayMap[AppDateUtils.startOfDay(day)] ?? const [],
                        selected: AppDateUtils.sameDay(day, selected),
                        isToday: AppDateUtils.sameDay(day, now),
                        locale: locale,
                        grace: grace,
                        now: now,
                        onTap: () => setState(
                          () => _selectedDay = AppDateUtils.startOfDay(day),
                        ),
                      ),
                    ),
                    if (day != days.last) const SizedBox(width: AppSpacing.xxs),
                  ],
                ],
              ),

              const SizedBox(height: AppSpacing.lg),
              AppSectionHeader(
                title: AppDateUtils.sameDay(selected, now)
                    ? l10n.histToday
                    : AppDateUtils.dayLabel(selected, locale),
                subtitle: l10n.histShowing(
                  l10n.histToday,
                  selectedEntries.length,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              if (selectedEntries.isEmpty)
                EmptyState(
                  compact: true,
                  icon: Icons.event_available_rounded,
                  title: l10n.homeEmptySchedule,
                  message: l10n.histEmpty,
                )
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < selectedEntries.length; i++) ...[
                        DoseListTile(
                          entry: selectedEntries[i],
                          grace: grace,
                          locale: locale,
                        ),
                        if (i != selectedEntries.length - 1)
                          const AppDivider(indent: AppSpacing.md),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.xs,
                children: [
                  _LegendDot(
                    color: theme.palette.success,
                    label: l10n.statusTaken,
                  ),
                  _LegendDot(
                    color: theme.colorScheme.error,
                    label: l10n.statusMissed,
                  ),
                  _LegendDot(
                    color: theme.colorScheme.onSurfaceVariant,
                    label: l10n.statusSkipped,
                  ),
                  _LegendDot(
                    color: theme.palette.warning,
                    label: l10n.statusPending,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One day in the week strip: weekday, date, and a dot per dose.
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.entries,
    required this.selected,
    required this.isToday,
    required this.locale,
    required this.grace,
    required this.now,
    required this.onTap,
  });

  final DateTime day;
  final List<DoseEntry> entries;
  final bool selected;
  final bool isToday;
  final String locale;
  final Duration grace;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: AppDateUtils.dayLabel(day, locale),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.controlRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.controlRadius,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              borderRadius: AppRadius.controlRadius,
              border: Border.all(
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.cardBorder,
                width: isToday ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  AppDateUtils.weekdayShort(day.weekday, locale),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                ),
                const SizedBox(height: 2),
                Text(
                  '${day.day}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: selected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                // Dots: a non-textual cue for how the day went. Limited to four
                // so the strip stays legible; the count is in the list below.
                SizedBox(
                  height: 8,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final e in entries.take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: doseVisual(
                                theme,
                                e.effectiveStatus(grace, now),
                              ).color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
