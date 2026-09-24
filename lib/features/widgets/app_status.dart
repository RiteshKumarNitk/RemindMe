import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/dose_status.dart';

/// Icon + colour pair for a dose outcome.
///
/// The icon is not decoration: it is what carries the meaning when the user
/// cannot distinguish the colours, and it is always paired with a word.
({IconData icon, Color color, Color background}) doseVisual(
  ThemeData theme,
  DoseStatus status,
) {
  final p = theme.palette;
  return switch (status) {
    DoseStatus.taken => (
      icon: Icons.check_circle_rounded,
      color: p.success,
      background: p.successContainer,
    ),
    DoseStatus.pending => (
      icon: Icons.schedule_rounded,
      color: theme.colorScheme.onSurfaceVariant,
      background: p.neutralContainer,
    ),
    DoseStatus.missed => (
      icon: Icons.error_rounded,
      color: theme.colorScheme.error,
      background: theme.colorScheme.errorContainer,
    ),
    DoseStatus.skipped => (
      icon: Icons.remove_circle_outline_rounded,
      color: theme.colorScheme.onSurfaceVariant,
      background: p.neutralContainer,
    ),
  };
}

/// Compact status pill: icon + word, tinted by outcome.
class DoseStatusBadge extends StatelessWidget {
  const DoseStatusBadge({
    super.key,
    required this.status,
    required this.label,
    this.dense = false,
  });

  final DoseStatus status;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = doseVisual(theme, status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.xs : AppSpacing.sm,
        vertical: dense ? 5 : AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: v.background,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(v.icon, size: dense ? 15 : AppSizes.iconSm, color: v.color),
          const SizedBox(width: AppSpacing.xxs + 2),
          Text(
            label,
            style: (dense ? theme.textTheme.labelSmall : theme.textTheme.labelMedium)
                ?.copyWith(color: v.color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Small grey pill for non-dose states (Active / Paused / Connected).
class AppPill extends StatelessWidget {
  const AppPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.background,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 2,
      ),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: AppRadius.chipRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: color),
          const SizedBox(width: AppSpacing.xxs + 2),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
