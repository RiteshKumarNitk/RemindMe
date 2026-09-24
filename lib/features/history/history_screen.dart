import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../state/app_state.dart';
import '../widgets/adherence_card.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/app_status.dart';
import '../widgets/app_surfaces.dart';

enum _Range { today, week, all }

/// What happened, grouped by day.
///
/// Reads top-to-bottom: summary → optional weekly pattern → the day groups.
/// Each dose is one row (time · medicine · outcome) so a user — or the family
/// member checking on them — can scan a day in a couple of seconds.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Range _range = _Range.today;
  DoseStatus? _statusFilter;
  int? _lastRevision;
  Future<(List<DoseEntry>, AdherenceStats)>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  (DateTime, DateTime) _bounds(DateTime now) {
    return switch (_range) {
      _Range.today => (
        AppDateUtils.startOfDay(now),
        AppDateUtils.startOfDay(now).add(const Duration(days: 1)),
      ),
      _Range.week => (
        AppDateUtils.startOfWeek(now),
        AppDateUtils.startOfWeek(now).add(const Duration(days: 7)),
      ),
      _Range.all => (
        now.subtract(const Duration(days: 90)),
        now.add(const Duration(days: 1)),
      ),
    };
  }

  Future<(List<DoseEntry>, AdherenceStats)> _load() {
    final appState = context.read<AppState>();
    final (start, end) = _bounds(DateTime.now());
    return appState.historyFor(start, end);
  }

  void _reload() => setState(() => _future = _load());

  Map<DateTime, _DailyStats> _computeDaily(
    List<DoseEntry> entries,
    DateTime weekStart,
    Duration grace,
  ) {
    final now = DateTime.now();
    final map = <DateTime, _DailyStats>{};
    for (var i = 0; i < 7; i++) {
      map[weekStart.add(Duration(days: i))] = _DailyStats();
    }
    for (final e in entries) {
      final day = AppDateUtils.startOfDay(e.dose.scheduledAt);
      final stats = map[day];
      if (stats == null) continue;
      switch (e.effectiveStatus(grace, now)) {
        case DoseStatus.taken:
          stats.taken++;
        case DoseStatus.missed:
          stats.missed++;
        case DoseStatus.skipped:
          stats.skipped++;
        case DoseStatus.pending:
          stats.pending++;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    if (_lastRevision != appState.revision) {
      _lastRevision = appState.revision;
      _future = _load();
    }
    final grace = appState.settings.graceDuration;
    final locale = appState.settings.settings.locale;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: AppPageHeader(
              title: l10n.histTitle,
              subtitle: switch (_range) {
                _Range.today => l10n.histToday,
                _Range.week => l10n.histThisWeek,
                _Range.all => l10n.histAll,
              },
            ),
          ),
          Padding(
            padding: AppSpacing.screenH,
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Range>(
                segments: [
                  ButtonSegment(value: _Range.today, label: Text(l10n.histToday)),
                  ButtonSegment(
                    value: _Range.week,
                    label: Text(l10n.histThisWeek),
                  ),
                  ButtonSegment(value: _Range.all, label: Text(l10n.histAll)),
                ],
                selected: {_range},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  _range = s.first;
                  _reload();
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<(List<DoseEntry>, AdherenceStats)>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SkeletonList(rows: 4);
                }
                final data = snapshot.data;
                if (data == null) {
                  return ErrorState(
                    title: l10n.errorTitle,
                    message: l10n.errorBody,
                    retryLabel: l10n.errorRetry,
                    onRetry: _reload,
                  );
                }
                final allEntries = data.$1;
                final stats = data.$2;

                if (allEntries.isEmpty) {
                  return EmptyState(
                    icon: Icons.history_rounded,
                    title: l10n.histEmpty,
                    message: l10n.histTrendGood,
                  );
                }

                final entries = _statusFilter == null
                    ? allEntries
                    : allEntries
                          .where(
                            (e) =>
                                e.effectiveStatus(grace, DateTime.now()) ==
                                _statusFilter,
                          )
                          .toList();

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    MediaQuery.paddingOf(context).bottom + 120,
                  ),
                  children: [
                    AdherenceCard(stats: stats, l10n: l10n),
                    if (_range == _Range.week && stats.total > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      _WeeklySummary(
                        dailyData: _computeDaily(
                          allEntries,
                          AppDateUtils.startOfWeek(DateTime.now()),
                          grace,
                        ),
                        weekStart: AppDateUtils.startOfWeek(DateTime.now()),
                        locale: locale,
                        stats: stats,
                        l10n: l10n,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    _StatusFilterBar(
                      selected: _statusFilter,
                      onSelected: (s) => setState(() => _statusFilter = s),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (entries.isEmpty)
                      EmptyState(
                        compact: true,
                        icon: Icons.filter_list_off_rounded,
                        title: l10n.histEmpty,
                        message: l10n.medSearchEmpty,
                      )
                    else
                      ..._grouped(entries, l10n, locale, grace),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _grouped(
    List<DoseEntry> entries,
    AppLocalizations l10n,
    String locale,
    Duration grace,
  ) {
    final now = DateTime.now();
    final groups = <DateTime, List<DoseEntry>>{};
    for (final e in entries) {
      final day = AppDateUtils.startOfDay(e.dose.scheduledAt);
      groups.putIfAbsent(day, () => []).add(e);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final day in days) {
      final list = groups[day]!
        ..sort((a, b) => b.dose.scheduledAt.compareTo(a.dose.scheduledAt));
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.lg,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            AppDateUtils.sameDay(day, now)
                ? l10n.histToday
                : AppDateUtils.dayLabel(day, locale),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
      );
      widgets.add(
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < list.length; i++) ...[
                _HistoryRow(
                  entry: list[i],
                  grace: grace,
                  locale: locale,
                  l10n: l10n,
                ),
                if (i != list.length - 1)
                  const AppDivider(indent: AppSpacing.md),
              ],
            ],
          ),
        ),
      );
    }
    return widgets;
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});

  final DoseStatus? selected;
  final ValueChanged<DoseStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <(DoseStatus?, String)>[
      (null, l10n.histAll),
      (DoseStatus.taken, l10n.statusTaken),
      (DoseStatus.missed, l10n.statusMissed),
      (DoseStatus.skipped, l10n.statusSkipped),
      (DoseStatus.pending, l10n.statusPending),
    ];
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (value, label) in items)
          ChoiceChip(
            label: Text(label),
            showCheckmark: false,
            selected: value == selected,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.entry,
    required this.grace,
    required this.locale,
    required this.l10n,
  });

  final DoseEntry entry;
  final Duration grace;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = entry.effectiveStatus(grace, DateTime.now());
    final visual = doseVisual(theme, status);
    final label = switch (status) {
      DoseStatus.taken => l10n.statusTaken,
      DoseStatus.skipped => l10n.statusSkipped,
      DoseStatus.missed => l10n.statusMissed,
      DoseStatus.pending => l10n.statusPending,
    };
    final actual = entry.dose.takenAt ?? entry.dose.skippedAt;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(visual.icon, size: AppSizes.iconLg, color: visual.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.medicine.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
                  style: theme.textTheme.bodyMedium,
                ),
                if (actual != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.histActual} · '
                    '${AppDateUtils.timeLabel(actual, locale)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          DoseStatusBadge(status: status, label: label, dense: true),
        ],
      ),
    );
  }
}

class _DailyStats {
  int taken = 0;
  int missed = 0;
  int skipped = 0;
  int pending = 0;
  int get total => taken + missed + skipped + pending;
}

/// Weekly pattern: a plain count line plus seven small stacked bars.
/// Shown only for "This Week", where the shape of the week is meaningful.
class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({
    required this.dailyData,
    required this.weekStart,
    required this.locale,
    required this.stats,
    required this.l10n,
  });

  final Map<DateTime, _DailyStats> dailyData;
  final DateTime weekStart;
  final String locale;
  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final maxDoses = days
        .map((d) => dailyData[d]?.total ?? 0)
        .fold(0, math.max)
        .toDouble();
    final good = stats.adherencePercent >= 70;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: l10n.histThisWeek,
            trailing: AppPill(
              label: good ? l10n.histTrendGood : l10n.histTrendNeedsWork,
              icon: good
                  ? Icons.trending_up_rounded
                  : Icons.trending_flat_rounded,
              color: good
                  ? theme.palette.success
                  : theme.palette.warning,
                background: good
                  ? theme.palette.successContainer
                  : theme.palette.warningContainer,
              ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: [
              _WeekCount(
                icon: Icons.check_circle_rounded,
                color: theme.palette.success,
                label: l10n.histTakenCount,
                value: stats.taken,
              ),
              _WeekCount(
                icon: Icons.error_rounded,
                color: theme.colorScheme.error,
                label: l10n.histMissedCount,
                value: stats.missed,
              ),
              _WeekCount(
                icon: Icons.remove_circle_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                label: l10n.histSkippedCount,
                value: stats.skipped,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 104,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days) ...[
                  Expanded(
                    child: _BarColumn(stats: dailyData[day], maxDoses: maxDoses),
                  ),
                  if (day != days.last) const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final day in days) ...[
                Expanded(
                  child: Text(
                    AppDateUtils.weekdayShort(day.weekday, locale),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                if (day != days.last) const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekCount extends StatelessWidget {
  const _WeekCount({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: color),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          '$value $label',
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({required this.stats, required this.maxDoses});

  final _DailyStats? stats;
  final double maxDoses;

  static const double _maxHeight = 88;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats?.total ?? 0;
    if (total == 0 || maxDoses == 0) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: AppRadius.pillRadius,
          ),
        ),
      );
    }

    final taken = stats?.taken ?? 0;
    final missed = stats?.missed ?? 0;
    final skipped = stats?.skipped ?? 0;
    final pending = stats?.pending ?? 0;
    final totalHeight = (total / maxDoses) * _maxHeight;

    Widget seg(int count, Color color) => count == 0
        ? const SizedBox.shrink()
        : Container(height: (count / total) * totalHeight, color: color);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            seg(pending, theme.colorScheme.surfaceContainerHighest),
            seg(skipped, theme.colorScheme.outline),
            seg(missed, theme.colorScheme.error),
            seg(taken, theme.palette.success),
          ],
        ),
      ),
    );
  }
}
