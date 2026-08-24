import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/dose_status.dart';

/// Icon + color used for a dose status.
(IconData, Color) statusVisual(ThemeData theme, DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return (Icons.check_circle_rounded, theme.successColor);
    case DoseStatus.skipped:
      return (Icons.remove_circle_rounded, theme.colorScheme.outline);
    case DoseStatus.missed:
      return (Icons.cancel_rounded, theme.missedColor);
    case DoseStatus.pending:
      return (Icons.alarm_rounded, theme.pendingColor);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, required this.label});

  final DoseStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = statusVisual(theme, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
