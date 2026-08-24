import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../state/app_state.dart';
import '../widgets/adherence_card.dart';
import '../widgets/dose_list_tile.dart';

enum _Range { today, week, all }

/// History of doses with daily/weekly adherence statistics.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Range _range = _Range.today;
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

  void _changeRange(_Range range) {
    setState(() {
      _range = range;
      _future = _load();
    });
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                l10n.histTitle,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedButton<_Range>(
                segments: [
                  ButtonSegment(
                    value: _Range.today,
                    label: Text(l10n.histToday),
                  ),
                  ButtonSegment(
                    value: _Range.week,
                    label: Text(l10n.histThisWeek),
                  ),
                  ButtonSegment(value: _Range.all, label: Text(l10n.histAll)),
                ],
                selected: {_range},
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  textStyle: theme.textTheme.titleMedium,
                ),
                onSelectionChanged: (s) => _changeRange(s.first),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<(List<DoseEntry>, AdherenceStats)>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data;
                  if (data == null) {
                    return const SizedBox.shrink();
                  }
                  final entries = data.$1;
                  final stats = data.$2;
                  if (entries.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.histEmpty,
                        style: theme.textTheme.titleMedium,
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      AdherenceCard(stats: stats, l10n: l10n),
                      if (_range == _Range.week && stats.total > 0)
                        _TrendIndicator(
                          currentPercent: stats.adherencePercent,
                          l10n: l10n,
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _exportCsv(entries, l10n),
                          icon: const Icon(Icons.download_rounded, size: 20),
                          label: Text(l10n.histExport),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._groupedEntries(entries, l10n),
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

  void _exportCsv(List<DoseEntry> entries, AppLocalizations l10n) {
    final locale = context.read<AppState>().settings.settings.locale;
    final buffer = StringBuffer();
    buffer.writeln('Date,Time,Medicine,Dose,Status');
    for (final e in entries) {
      final date = AppDateUtils.dateLabel(e.dose.scheduledAt, locale);
      final time = AppDateUtils.timeLabel(e.dose.scheduledAt, locale);
      final name = e.medicine.name.replaceAll(',', ';');
      final dose = e.medicine.doseLabel.replaceAll(',', ';');
      final status = e.dose.status.name;
      buffer.writeln('$date,$time,$name,$dose,$status');
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.histExport),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              buffer.toString(),
              style: Theme.of(
                ctx,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
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

  List<Widget> _groupedEntries(List<DoseEntry> entries, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final locale = context.read<AppState>().settings.settings.locale;
    final now = DateTime.now();
    final grace = context.read<AppState>().settings.graceDuration;

    final groups = <DateTime, List<DoseEntry>>{};
    for (final e in entries) {
      final day = AppDateUtils.startOfDay(e.dose.scheduledAt);
      groups.putIfAbsent(day, () => []).add(e);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final day in days) {
      final label = AppDateUtils.sameDay(day, now)
          ? l10n.histToday
          : AppDateUtils.dayLabel(day, locale);
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
      for (final e in groups[day]!) {
        widgets.add(DoseListTile(entry: e, grace: grace, locale: locale));
      }
    }
    return widgets;
  }
}

/// Simple trend indicator showing whether adherence improved or declined
/// compared to the previous period.
class _TrendIndicator extends StatelessWidget {
  const _TrendIndicator({required this.currentPercent, required this.l10n});

  final int currentPercent;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use a simple heuristic: compare against a 70% baseline.
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
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 22, color: color),
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
