import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/adherence_stats.dart';

/// Shows adherence % with Taken / Missed / Skipped counts. Shared by the
/// History screen and the caregiver dashboard.
class AdherenceCard extends StatelessWidget {
  const AdherenceCard({super.key, required this.stats, required this.l10n});

  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.histAdherence,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '${stats.adherencePercent}%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    l10n.histTotal(stats.total),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _CountRow(
                    icon: Icons.check_circle_rounded,
                    color: theme.successColor,
                    label: l10n.histTakenCount,
                    value: stats.taken,
                  ),
                  const SizedBox(height: 10),
                  _CountRow(
                    icon: Icons.cancel_rounded,
                    color: theme.missedColor,
                    label: l10n.histMissedCount,
                    value: stats.missed,
                  ),
                  const SizedBox(height: 10),
                  _CountRow(
                    icon: Icons.remove_circle_rounded,
                    color: theme.colorScheme.outline,
                    label: l10n.histSkippedCount,
                    value: stats.skipped,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
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
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const Spacer(),
        Text(
          '$value',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
