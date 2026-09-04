import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../state/app_state.dart';

/// Generates a formatted adherence report for doctor visits.
/// Shows a preview and allows sharing via any app.
class DoctorReportScreen extends StatefulWidget {
  const DoctorReportScreen({super.key});

  @override
  State<DoctorReportScreen> createState() => _DoctorReportScreenState();
}

class _DoctorReportScreenState extends State<DoctorReportScreen> {
  int _days = 7; // Default: last 7 days
  String? _reportText;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  void _generateReport() async {
    final appState = context.read<AppState>();
    final now = DateTime.now();
    final start = now.subtract(Duration(days: _days));
    final locale = appState.settings.settings.locale;
    final grace = appState.settings.graceDuration;

    final result = await appState.historyFor(start, now);
    final entries = result.$1;
    final stats = result.$2;

    final buffer = StringBuffer();
    buffer.writeln('╔══════════════════════════════════════╗');
    buffer.writeln('║     DOSEWISE MEDICINE REPORT         ║');
    buffer.writeln('╚══════════════════════════════════════╝');
    buffer.writeln();
    buffer.writeln('Patient: ${appState.settings.userName.isNotEmpty ? appState.settings.userName : "N/A"}');
    buffer.writeln('Report Period: $_days days');
    buffer.writeln(
      'Generated: ${AppDateUtils.dateLabel(now, locale)}',
    );
    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('ADHERENCE SUMMARY');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('  Overall Adherence: ${stats.adherencePercent}%');
    buffer.writeln('  Total Doses:       ${stats.total}');
    buffer.writeln('  Taken:             ${stats.taken}');
    buffer.writeln('  Missed:            ${stats.missed}');
    buffer.writeln('  Skipped:           ${stats.skipped}');
    buffer.writeln();

    // Per-medicine breakdown
    final perMed = <String, Map<String, int>>{};
    for (final e in entries) {
      final name = e.medicine.name;
      perMed.putIfAbsent(name, () => {
        'taken': 0,
        'missed': 0,
        'skipped': 0,
      });
      final status = e.effectiveStatus(grace, now);
      switch (status) {
        case DoseStatus.taken:
          perMed[name]!['taken'] = (perMed[name]!['taken'] ?? 0) + 1;
        case DoseStatus.missed:
          perMed[name]!['missed'] = (perMed[name]!['missed'] ?? 0) + 1;
        case DoseStatus.skipped:
          perMed[name]!['skipped'] = (perMed[name]!['skipped'] ?? 0) + 1;
        case DoseStatus.pending:
          break;
      }
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('MEDICINE BREAKDOWN');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    for (final entry in perMed.entries) {
      final name = entry.key;
      final data = entry.value;
      final taken = data['taken'] ?? 0;
      final missed = data['missed'] ?? 0;
      final skipped = data['skipped'] ?? 0;
      final total = taken + missed + skipped;
      final pct = total > 0 ? (taken * 100 / total).round() : 0;

      buffer.writeln();
      buffer.writeln('  $name ($pct% adherence)');
      buffer.writeln('    Taken: $taken | Missed: $missed | Skipped: $skipped');

      // Find the medicine's dose details
      final medEntry = entries.firstWhere(
        (e) => e.medicine.name == name,
        orElse: () => entries.first,
      );
      if (medEntry.medicine.doseLabel.isNotEmpty) {
        buffer.writeln('    Dose: ${medEntry.medicine.doseLabel}');
      }
      if (medEntry.medicine.notes.isNotEmpty) {
        buffer.writeln('    Notes: ${medEntry.medicine.notes}');
      }
    }

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('DETAILED LOG');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Group by day
    final dayMap = <String, List<DoseEntry>>{};
    for (final e in entries) {
      final dayKey = AppDateUtils.dateLabel(e.dose.scheduledAt, locale);
      dayMap.putIfAbsent(dayKey, () => []).add(e);
    }

    for (final dayEntry in dayMap.entries) {
      buffer.writeln();
      buffer.writeln('  ${dayEntry.key}');
      for (final e in dayEntry.value) {
        final time = AppDateUtils.timeLabel(e.dose.scheduledAt, locale);
        final status = e.effectiveStatus(grace, now);
        final actual = e.dose.takenAt != null
            ? ' at ${AppDateUtils.timeLabel(e.dose.takenAt!, locale)}'
            : e.dose.skippedAt != null
                ? ' at ${AppDateUtils.timeLabel(e.dose.skippedAt!, locale)}'
                : '';
        buffer.writeln(
          '    $time ${e.medicine.name} ${e.medicine.doseLabel} → ${status.name}$actual',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('This report was generated by DoseWise');
    buffer.writeln('DoseWise is a reminder tool only — not medical advice.');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (mounted) {
      setState(() => _reportText = buffer.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.histExport),
      ),
      body: Column(
        children: [
          // Period selector
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'Report period:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                for (final days in [7, 14, 30]) ...[
                  if (days != 7) const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('$days days'),
                    selected: _days == days,
                    onSelected: (_) {
                      setState(() => _days = days);
                      _generateReport();
                    },
                  ),
                ],
              ],
            ),
          ),

          // Report preview
          Expanded(
            child: _reportText == null
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        _reportText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
          ),

          // Share button
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_reportText != null) {
                        Clipboard.setData(
                          ClipboardData(text: _reportText!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Report copied to clipboard'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_reportText != null) {
                        Share.share(
                          _reportText!,
                          subject: 'DoseWise Medicine Report',
                        );
                      }
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share Report'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
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
