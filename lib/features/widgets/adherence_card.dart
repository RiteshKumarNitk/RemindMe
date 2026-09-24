import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/adherence_stats.dart';
import 'app_surfaces.dart';

/// Adherence percentage with Taken / Missed / Skipped counts.
/// Shared by the History screen and the caregiver dashboard.
///
/// The percentage is the headline; the counts are supporting detail, so a
/// carer can read the answer at a glance and the nuance on a second look.
class AdherenceCard extends StatelessWidget {
  const AdherenceCard({super.key, required this.stats, required this.l10n});

  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = stats.adherencePercent;
    final color = pct >= 80 ? theme.palette.success : theme.colorScheme.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.histAdherence, style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$pct%',
                style: theme.textTheme.displaySmall?.copyWith(color: color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  l10n.histTotal(stats.total),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: AppRadius.pillRadius,
            child: LinearProgressIndicator(
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _Count(
                icon: Icons.check_circle_rounded,
                color: theme.palette.success,
                label: l10n.histTakenCount,
                value: stats.taken,
              ),
              _Count(
                icon: Icons.error_rounded,
                color: theme.colorScheme.error,
                label: l10n.histMissedCount,
                value: stats.missed,
              ),
              _Count(
                icon: Icons.remove_circle_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant,
                label: l10n.histSkippedCount,
                value: stats.skipped,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
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
        Text(label, style: theme.textTheme.bodyMedium),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          '$value',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
