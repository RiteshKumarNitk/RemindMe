import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../data/models/food_instruction.dart';
import '../../state/app_state.dart';

enum _Range { today, week, all }

/// History of doses with adherence stats, range + status filtering and a
/// full per-dose breakdown (scheduled vs actual time, food, status).
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
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    if (_lastRevision != appState.revision) {
      _lastRevision = appState.revision;
      _future = _load();
    }
    final grace = appState.settings.graceDuration;
    final locale = appState.settings.settings.locale;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Text(
                l10n.histTitle,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _RangeChip(
                    label: l10n.histToday,
                    selected: _range == _Range.today,
                    onTap: () {
                      _range = _Range.today;
                      _reload();
                    },
                  ),
                  const SizedBox(width: 8),
                  _RangeChip(
                    label: l10n.histThisWeek,
                    selected: _range == _Range.week,
                    onTap: () {
                      _range = _Range.week;
                      _reload();
                    },
                  ),
                  const SizedBox(width: 8),
                  _RangeChip(
                    label: l10n.histAll,
                    selected: _range == _Range.all,
                    onTap: () {
                      _range = _Range.all;
                      _reload();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<(List<DoseEntry>, AdherenceStats)>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data;
                  if (data == null) return const SizedBox.shrink();
                  final allEntries = data.$1;
                  final stats = data.$2;

                  if (allEntries.isEmpty) {
                    return _Empty(text: l10n.histEmpty);
                  }

                  final entries = _statusFilter == null
                      ? allEntries
                      : allEntries
                          .where((e) =>
                              e.effectiveStatus(grace, DateTime.now()) ==
                              _statusFilter)
                          .toList();

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      MediaQuery.paddingOf(context).bottom + 108,
                    ),
                    children: [
                      _SummaryCard(stats: stats, l10n: l10n),
                      if (_range == _Range.week && stats.total > 0) ...[
                        const SizedBox(height: 14),
                        _WeeklyBarChart(
                          dailyData: _computeDaily(
                            allEntries,
                            AppDateUtils.startOfWeek(DateTime.now()),
                            grace,
                          ),
                          weekStart: AppDateUtils.startOfWeek(DateTime.now()),
                          locale: locale,
                        ),
                        _TrendIndicator(
                          currentPercent: stats.adherencePercent,
                          l10n: l10n,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _StatusFilterBar(
                        selected: _statusFilter,
                        onSelected: (s) =>
                            setState(() => _statusFilter = s),
                      ),
                      const SizedBox(height: 12),

                      if (entries.isEmpty)
                        _Empty(text: l10n.histEmpty)
                      else
                        ..._grouped(entries, l10n, locale, grace, theme),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _grouped(
    List<DoseEntry> entries,
    AppLocalizations l10n,
    String locale,
    Duration grace,
    ThemeData theme,
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
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(
            children: [
              // Colored dot for visual identification
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppDateUtils.sameDay(day, now)
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppDateUtils.sameDay(day, now)
                    ? '📍 ${l10n.histToday}'
                    : AppDateUtils.dayLabel(day, locale),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 2,
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ],
          ),
        ),
      );
      for (final e in list) {
        widgets.add(_HistoryTile(entry: e, grace: grace, locale: locale));
      }
    }
    return widgets;
  }
}

// ---------------------------------------------------------------------------

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: selected
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusFilterBar extends StatelessWidget {
  const _StatusFilterBar({required this.selected, required this.onSelected});

  final DoseStatus? selected;
  final ValueChanged<DoseStatus?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = <(DoseStatus?, String, Color)>[
      (null, l10n.histAll, theme.colorScheme.primary),
      (DoseStatus.taken, l10n.statusTaken, theme.successColor),
      (DoseStatus.missed, l10n.statusMissed, theme.missedColor),
      (DoseStatus.skipped, l10n.statusSkipped, theme.colorScheme.outline),
      (DoseStatus.pending, l10n.statusPending, theme.pendingColor),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label, color) = items[i];
          final isSel = value == selected;
          return Material(
            color: isSel ? color : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(19),
            child: InkWell(
              borderRadius: BorderRadius.circular(19),
              onTap: () => onSelected(value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.l10n});

  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = stats.adherencePercent;
    final ringColor = pct >= 80 ? theme.successColor : theme.accentColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Larger progress ring for elderly readability
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(ringColor),
                  ),
                ),
                Text(
                  '$pct%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ringColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.histAdherence,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.histTotal(stats.total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    _Count(theme.successColor, l10n.histTakenCount, stats.taken),
                    _Count(theme.missedColor, l10n.histMissedCount, stats.missed),
                    _Count(theme.colorScheme.outline, l10n.histSkippedCount,
                        stats.skipped),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.color, this.label, this.value);
  final Color color;
  final String label;
  final int value;

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
        const SizedBox(width: 6),
        Text(
          '$value $label',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.entry,
    required this.grace,
    required this.locale,
  });

  final DoseEntry entry;
  final Duration grace;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = entry.effectiveStatus(grace, DateTime.now());

    final (Color color, IconData icon, String label) = switch (status) {
      DoseStatus.taken => (
        theme.successColor,
        Icons.check_circle_rounded,
        l10n.statusTaken,
      ),
      DoseStatus.skipped => (
        theme.colorScheme.outline,
        Icons.do_not_disturb_on_rounded,
        l10n.statusSkipped,
      ),
      DoseStatus.missed => (
        theme.missedColor,
        Icons.cancel_rounded,
        l10n.statusMissed,
      ),
      DoseStatus.pending => (
        theme.pendingColor,
        Icons.schedule_rounded,
        l10n.statusPending,
      ),
    };

    final food = switch (entry.medicine.foodInstruction) {
      FoodInstruction.none => '',
      FoodInstruction.before => l10n.foodBefore,
      FoodInstruction.after => l10n.foodAfter,
      FoodInstruction.withFood => l10n.foodWith,
    };
    final sub = [
      if (entry.medicine.doseLabel.isNotEmpty) entry.medicine.doseLabel,
      if (food.isNotEmpty) food,
    ].join('  •  ');

    final actualTime = entry.dose.takenAt ?? entry.dose.skippedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status == DoseStatus.missed
              ? theme.missedColor.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Larger status icon for elderly readability
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.medicine.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _Badge(color: color, label: label),
                  ],
                ),
                if (sub.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                _TimeLine(
                  label: l10n.histScheduled,
                  time: AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
                ),
                if (actualTime != null)
                  _TimeLine(
                    label: l10n.histActual,
                    time: AppDateUtils.timeLabel(actualTime, locale),
                    color: color,
                  ),
                if (status == DoseStatus.pending &&
                    entry.dose.snoozedUntil != null)
                  _TimeLine(
                    label: l10n.statusSnoozed,
                    time: AppDateUtils.timeLabel(
                      entry.dose.snoozedUntil!,
                      locale,
                    ),
                    color: theme.pendingColor,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeLine extends StatelessWidget {
  const _TimeLine({required this.label, required this.time, this.color});

  final String label;
  final String time;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: 1),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 13, color: c),
          const SizedBox(width: 5),
          Text(
            '$label  $time',
            style: theme.textTheme.bodySmall?.copyWith(color: c),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_rounded,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
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

/// Weekly bar chart — 7 stacked bars (Mon–Sun) showing taken (green),
/// missed (red), and skipped (gray) counts per day. Shown only in the
/// "This Week" range to give elderly users an at-a-glance weekly pattern.
class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({
    required this.dailyData,
    required this.weekStart,
    required this.locale,
  });

  final Map<DateTime, _DailyStats> dailyData;
  final DateTime weekStart;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    final maxDoses = days
        .map((d) => dailyData[d]?.total ?? 0)
        .fold(0, math.max)
        .toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days) ...[
                  Expanded(
                    child: _BarColumn(
                      stats: dailyData[day],
                      maxHeight: 100,
                      maxDoses: maxDoses,
                    ),
                  ),
                  if (day != days.last) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final day in days) ...[
                Expanded(
                  child: Text(
                    AppDateUtils.weekdayShort(day.weekday, locale),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (day != days.last) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.stats,
    required this.maxHeight,
    required this.maxDoses,
  });

  final _DailyStats? stats;
  final double maxHeight;
  final double maxDoses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = stats?.total ?? 0;
    if (total == 0 || maxDoses == 0) {
      return SizedBox(
        height: maxHeight,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
    }

    final taken = stats?.taken ?? 0;
    final missed = stats?.missed ?? 0;
    final skipped = stats?.skipped ?? 0;
    final pending = stats?.pending ?? 0;

    final totalHeight = (total / maxDoses) * maxHeight;
    final takenHeight = (taken / total) * totalHeight;
    final missedHeight = (missed / total) * totalHeight;
    final skippedHeight = (skipped / total) * totalHeight;

    return SizedBox(
      height: maxHeight,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending > 0)
                Container(
                  height: (pending / total) * totalHeight,
                  color: theme.pendingColor.withValues(alpha: 0.3),
                ),
              if (skipped > 0)
                Container(
                  height: skippedHeight,
                  color: theme.colorScheme.outline.withValues(alpha: 0.5),
                ),
              if (missed > 0)
                Container(
                  height: missedHeight,
                  color: theme.missedColor,
                ),
              if (taken > 0)
                Container(
                  height: takenHeight,
                  color: theme.successColor,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Whether adherence improved or declined vs a 70% baseline.
class _TrendIndicator extends StatelessWidget {
  const _TrendIndicator({required this.currentPercent, required this.l10n});

  final int currentPercent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGood = currentPercent >= 70;
    final icon = isGood
        ? Icons.trending_up_rounded
        : currentPercent >= 50
            ? Icons.trending_flat_rounded
            : Icons.trending_down_rounded;
    final color = isGood
        ? theme.successColor
        : currentPercent >= 50
            ? theme.pendingColor
            : theme.missedColor;
    final label = isGood ? l10n.histTrendGood : l10n.histTrendNeedsWork;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
