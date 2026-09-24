import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import 'app_status.dart';

/// One resolved dose, as a plain row: medicine, time, outcome.
/// Shared by the History screen and the caregiver dashboard.
class DoseListTile extends StatelessWidget {
  const DoseListTile({
    super.key,
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
    final visual = doseVisual(theme, status);
    final statusLabel = switch (status) {
      DoseStatus.taken => l10n.statusTaken,
      DoseStatus.skipped => l10n.statusSkipped,
      DoseStatus.missed => l10n.statusMissed,
      DoseStatus.pending => l10n.statusPending,
    };
    final dose = entry.medicine.doseLabel;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(visual.icon, size: AppSizes.iconLg, color: visual.color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.medicine.name,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
                    if (dose.isNotEmpty) dose,
                  ].join(' · '),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          DoseStatusBadge(status: status, label: statusLabel, dense: true),
        ],
      ),
    );
  }
}
