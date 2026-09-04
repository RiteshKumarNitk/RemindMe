import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../state/app_state.dart';

/// Adherence report with weekly bar charts, streak tracking, and
/// per-medicine breakdown. Designed for elderly users and their caregivers.
class AdherenceReportScreen extends StatefulWidget {
  const AdherenceReportScreen({super.key});

  @override
  State<AdherenceReportScreen> createState() => _AdherenceReportScreenState();
}

class _AdherenceReportScreenState extends State<AdherenceReportScreen> {
  int _weekOffset = 0; // 0 = this week, -1 = last week, etc.

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final now = DateTime.now();
    final locale = appState.settings.settings.locale;
    final grace = appState.settings.graceDuration;

    // Compute the week range
    final weekStart = AppDateUtils.startOfWeek(now).add(
      Duration(days: 7 * _weekOffset),
    );
    final weekEnd = weekStart.add(const Duration(days: 7));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.histTitle),
        actions: [
          IconButton(
            onPressed: () => _shareReport(appState, weekStart, weekEnd, l10n),
            icon: const Icon(Icons.share_rounded),
            tooltip: l10n.histExport,
          ),
        ],
      ),
      body: FutureBuilder<List<DoseEntry>>(
        future: appState.historyFor(weekStart, weekEnd).then((r) => r.$1),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return _EmptyWeek(l10n: l10n, theme: theme);
          }

          // Group by day
          final dailyData = _computeDaily(entries, weekStart, grace);
          final weekStats = _computeWeekStats(dailyData);
          final perMed = _computePerMedicine(entries, grace);
          final streak = _computeStreak(appState, grace, now);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Week navigation
              _WeekNavigator(
                weekStart: weekStart,
                weekEnd: weekEnd,
                locale: locale,
                canGoForward: _weekOffset < 0,
                onPrevious: () => setState(() => _weekOffset--),
                onNext: () => setState(() => _weekOffset++),
                l10n: l10n,
              ),

              const SizedBox(height: 16),

              // Overall adherence ring
              _AdherenceRing(
                taken: weekStats.taken,
                missed: weekStats.missed,
                skipped: weekStats.skipped,
                l10n: l10n,
              ),

              const SizedBox(height: 20),

              // Streak card
              if (streak > 0)
                _StreakCard(streak: streak, l10n: l10n),

              const SizedBox(height: 20),

              // Weekly bar chart
              Text(
                l10n.histThisWeek,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _WeeklyBarChart(
                dailyData: dailyData,
                weekStart: weekStart,
                locale: locale,
                l10n: l10n,
              ),

              const SizedBox(height: 24),

              // Per-medicine breakdown
              Text(
                l10n.navMeds,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...perMed.entries.map(
                (e) => _MedicineAdherenceTile(
                  name: e.key,
                  stats: e.value,
                  l10n: l10n,
                ),
              ),

              const SizedBox(height: 24),

              // Export button
              _ExportButton(
                onTap: () =>
                    _shareReport(appState, weekStart, weekEnd, l10n),
                l10n: l10n,
              ),
            ],
          );
        },
      ),
    );
  }

  Map<DateTime, _DayStats> _computeDaily(
    List<DoseEntry> entries,
    DateTime weekStart,
    Duration grace,
  ) {
    final now = DateTime.now();
    final map = <DateTime, _DayStats>{};
    for (var i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      map[day] = _DayStats();
    }
    for (final e in entries) {
      final day = AppDateUtils.startOfDay(e.dose.scheduledAt);
      final stats = map[day];
      if (stats == null) continue;
      final status = e.effectiveStatus(grace, now);
      switch (status) {
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

  _WeekStats _computeWeekStats(Map<DateTime, _DayStats> daily) {
    int taken = 0, missed = 0, skipped = 0;
    for (final d in daily.values) {
      taken += d.taken;
      missed += d.missed;
      skipped += d.skipped;
    }
    return _WeekStats(taken: taken, missed: missed, skipped: skipped);
  }

  Map<String, AdherenceStats> _computePerMedicine(
    List<DoseEntry> entries,
    Duration grace,
  ) {
    final now = DateTime.now();
    final map = <String, AdherenceStats>{};
    for (final e in entries) {
      final status = e.effectiveStatus(grace, now);
      final existing = map[e.medicine.name];
      map[e.medicine.name] = (existing ?? const AdherenceStats()).add(status);
    }
    return map;
  }

  int _computeStreak(AppState appState, Duration grace, DateTime now) {
    // Count consecutive days with 100% adherence going back from today
    int streak = 0;
    final todayDoses = appState.todayDoses;
    if (todayDoses.isEmpty) return 0;

    // Check today first
    final todayStats = appState.todayStats;
    if (todayStats.resolved > 0 && todayStats.adherencePercent == 100) {
      streak = 1;
    } else if (todayStats.resolved > 0) {
      return 0; // Today has misses, no streak
    }

    // Go back day by day
    var day = AppDateUtils.startOfDay(now).subtract(const Duration(days: 1));
    for (var i = 0; i < 90; i++) {
      // Use a simple heuristic: if we can't compute, stop
      if (i > 30) break; // Cap at 30 days
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void _shareReport(
    AppState appState,
    DateTime start,
    DateTime end,
    AppLocalizations l10n,
  ) async {
    final result = await appState.historyFor(start, end);
    final entries = result.$1;
    final stats = result.$2;
    final locale = appState.settings.settings.locale;

    final buffer = StringBuffer();
    buffer.writeln('=== DoseWise Adherence Report ===');
    buffer.writeln(
      '${AppDateUtils.dateLabel(start, locale)} — ${AppDateUtils.dateLabel(end, locale)}',
    );
    buffer.writeln();
    buffer.writeln(
      'Adherence: ${stats.adherencePercent}% (${stats.taken} taken, ${stats.missed} missed, ${stats.skipped} skipped)',
    );
    buffer.writeln();
    buffer.writeln('--- Dose Details ---');

    for (final e in entries) {
      final date = AppDateUtils.dateLabel(e.dose.scheduledAt, locale);
      final time = AppDateUtils.timeLabel(e.dose.scheduledAt, locale);
      final status = e.effectiveStatus(appState.settings.graceDuration, DateTime.now());
      buffer.writeln(
        '$date $time | ${e.medicine.name} | ${e.medicine.doseLabel} | ${status.name}',
      );
    }

    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.histExport),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: SelectableText(
                buffer.toString(),
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.btnClose),
            ),
          ],
        ),
      );
    }
  }
}

class _DayStats {
  int taken = 0;
  int missed = 0;
  int skipped = 0;
  int pending = 0;
  int get total => taken + missed + skipped + pending;
  int get resolved => taken + missed + skipped;
}

class _WeekStats {
  final int taken;
  final int missed;
  final int skipped;
  const _WeekStats({
    required this.taken,
    required this.missed,
    required this.skipped,
  });
}

// ─── Week Navigator ─────────────────────────────────────────────────────────

class _WeekNavigator extends StatelessWidget {
  const _WeekNavigator({
    required this.weekStart,
    required this.weekEnd,
    required this.locale,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
    required this.l10n,
  });

  final DateTime weekStart;
  final DateTime weekEnd;
  final String locale;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final startLabel = AppDateUtils.dateLabel(weekStart, locale);
    final endLabel = AppDateUtils.dateLabel(
      weekEnd.subtract(const Duration(days: 1)),
      locale,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Text(
          '$startLabel — $endLabel',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        IconButton(
          onPressed: canGoForward ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

// ─── Adherence Ring ─────────────────────────────────────────────────────────

class _AdherenceRing extends StatelessWidget {
  const _AdherenceRing({
    required this.taken,
    required this.missed,
    required this.skipped,
    required this.l10n,
  });

  final int taken;
  final int missed;
  final int skipped;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = taken + missed + skipped;
    final pct = total > 0 ? (taken * 100 / total).round() : 0;
    final color = pct >= 80
        ? theme.successColor
        : pct >= 50
            ? theme.pendingColor
            : theme.missedColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
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
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '$pct%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.histAdherence,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _StatDot(
                  color: theme.successColor,
                  label: l10n.histTakenCount,
                  value: taken,
                ),
                const SizedBox(height: 4),
                _StatDot(
                  color: theme.missedColor,
                  label: l10n.histMissedCount,
                  value: missed,
                ),
                const SizedBox(height: 4),
                _StatDot(
                  color: theme.colorScheme.outline,
                  label: l10n.histSkippedCount,
                  value: skipped,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDot extends StatelessWidget {
  const _StatDot({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          '$value $label',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Streak Card ────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.l10n});
  final int streak;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.successColor.withValues(alpha: 0.15),
            theme.successColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.successColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              l10n.homeStreak(streak),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.successColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Weekly Bar Chart ───────────────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({
    required this.dailyData,
    required this.weekStart,
    required this.locale,
    required this.l10n,
  });

  final Map<DateTime, _DayStats> dailyData;
  final DateTime weekStart;
  final String locale;
  final AppLocalizations l10n;

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
          // Bars
          SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final day in days) ...[
                  Expanded(
                    child: _BarColumn(
                      stats: dailyData[day],
                      maxHeight: 120,
                      maxDoses: maxDoses,
                    ),
                  ),
                  if (day != days.last) const SizedBox(width: 4),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Day labels
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

  final _DayStats? stats;
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

// ─── Medicine Adherence Tile ────────────────────────────────────────────────

class _MedicineAdherenceTile extends StatelessWidget {
  const _MedicineAdherenceTile({
    required this.name,
    required this.stats,
    required this.l10n,
  });

  final String name;
  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = stats.adherencePercent;
    final color = pct >= 80
        ? theme.successColor
        : pct >= 50
            ? theme.pendingColor
            : theme.missedColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          // Mini progress ring
          SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: (pct / 100).clamp(0.0, 1.0),
                    strokeWidth: 5,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '$pct',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${stats.taken} ${l10n.histTakenCount} · ${stats.missed} ${l10n.histMissedCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Export Button ──────────────────────────────────────────────────────────

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onTap, required this.l10n});
  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.share_rounded),
        label: Text(l10n.histExport),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ────────────────────────────────────────────────────────────

class _EmptyWeek extends StatelessWidget {
  const _EmptyWeek({required this.l10n, required this.theme});
  final AppLocalizations l10n;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 56,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.histEmpty,
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
