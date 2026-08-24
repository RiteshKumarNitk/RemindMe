import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import 'status_view.dart';

/// One dose row: medicine name, time and outcome chip. Shared by the History
/// screen and the caregiver dashboard.
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
    final (icon, color) = statusVisual(theme, status);
    final statusLabel = switch (status) {
      DoseStatus.taken => l10n.statusTaken,
      DoseStatus.skipped => l10n.statusSkipped,
      DoseStatus.missed => l10n.statusMissed,
      DoseStatus.pending => l10n.statusPending,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.medicine.name, style: theme.textTheme.titleMedium),
                  Text(
                    AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StatusChip(status: status, label: statusLabel),
          ],
        ),
      ),
    );
  }
}
