import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/medicine_frequency.dart';
import 'app_buttons.dart';
import 'app_status.dart';
import 'app_surfaces.dart';

/// One row of the day's schedule, laid out as a timeline entry:
///
/// ```
/// ✓   8:00 AM                         Taken
///     BP Tablet
///     1 tablet — After food
/// ```
///
/// The status is written out and icon-marked as well as coloured, so a user
/// who cannot tell green from red still reads the outcome correctly.
class MedicineDoseTile extends StatelessWidget {
  const MedicineDoseTile({
    super.key,
    required this.entry,
    required this.locale,
    required this.grace,
    this.isNext = false,
    this.onTake,
    this.onSkip,
    this.onOpen,
    this.railTop = true,
    this.railBottom = true,
  });

  final DoseEntry entry;
  final String locale;
  final Duration grace;
  final bool isNext;
  final VoidCallback? onTake;
  final VoidCallback? onSkip;
  final VoidCallback? onOpen;
  final bool railTop;
  final bool railBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final status = entry.effectiveStatus(grace, DateTime.now());
    final visual = doseVisual(theme, status);
    final done = status == DoseStatus.taken || status == DoseStatus.skipped;
    final medicine = entry.medicine;
    final food = _foodLabel(l10n, medicine.foodInstruction);
    final doseLine = [
      if (medicine.doseLabel.isNotEmpty) medicine.doseLabel,
      if (food.isNotEmpty) food,
    ].join(' — ');
    final isMissed = status == DoseStatus.missed;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: AppSizes.timelineRail,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 10,
                  color: railTop ? theme.cardBorder : Colors.transparent,
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: visual.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: visual.color, width: 1.5),
                  ),
                  child: Icon(visual.icon, size: 15, color: visual.color),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: railBottom ? theme.cardBorder : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: onOpen,
              borderRadius: AppRadius.controlRadius,
              child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.xxs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: done
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      if (isNext) ...[
                        const SizedBox(width: AppSpacing.xs),
                        AppPill(
                          label: l10n.homeNextMedicine,
                          icon: Icons.play_arrow_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                      const Spacer(),
                      DoseStatusBadge(
                        status: status,
                        dense: true,
                        label: switch (status) {
                          DoseStatus.taken => l10n.statusTaken,
                          DoseStatus.pending =>
                            isNext ? l10n.homeDueNow : l10n.statusPending,
                          DoseStatus.missed => l10n.statusMissed,
                          DoseStatus.skipped => l10n.statusSkipped,
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    medicine.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: done ? TextDecoration.lineThrough : null,
                      decorationColor: theme.colorScheme.onSurfaceVariant,
                      color: done
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  if (doseLine.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        doseLine,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (isMissed) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppInfoNote(
                      tone: AppNoteTone.danger,
                      title: l10n.homeMissedTitle,
                      message: l10n.homeMissedBody,
                      actionLabel: onTake == null ? null : l10n.homeMarkAsTaken,
                      actionIcon: Icons.check_rounded,
                      onAction: onTake,
                    ),
                  ] else if (!done && onTake != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        AppButton(
                          label: l10n.homeTaken,
                          icon: Icons.check_rounded,
                          height: 48,
                          expand: false,
                          onPressed: onTake,
                        ),
                        if (onSkip != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          AppButton(
                            label: l10n.homeSkip,
                            icon: Icons.close_rounded,
                            tone: AppButtonTone.quiet,
                            height: 48,
                            expand: false,
                            onPressed: onSkip,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _foodLabel(AppLocalizations l10n, FoodInstruction food) => switch (food) {
  FoodInstruction.none => '',
  FoodInstruction.before => l10n.foodBefore,
  FoodInstruction.after => l10n.foodAfter,
  FoodInstruction.withFood => l10n.foodWith,
};

/// Row in "My medicines": name, dose + schedule summary, active state.
///
/// Only one visible action (the menu) — per-medicine actions live in a sheet,
/// so rows stay calm and every control keeps a large tap target.
class MedicineSummaryTile extends StatelessWidget {
  const MedicineSummaryTile({
    super.key,
    required this.medicine,
    required this.locale,
    this.onTap,
    this.onMenu,
  });

  final Medicine medicine;
  final String locale;
  final VoidCallback? onTap;
  final VoidCallback? onMenu;

  String _scheduleSummary(AppLocalizations l10n) {
    final times = medicine.schedules
        .map(
          (s) => AppDateUtils.timeLabel(
            DateTime(2024, 1, 1, s.hour, s.minute),
            locale,
          ),
        )
        .join(' · ');
    final freq = switch (medicine.frequency) {
      MedicineFrequency.daily => l10n.freqEveryDay,
      MedicineFrequency.multiple => l10n.freqMultiple,
      MedicineFrequency.specificDays => medicine.selectedDays.isEmpty
          ? l10n.freqSpecificDays
          : medicine.selectedDays
              .map((d) => AppDateUtils.weekdayShort(d, locale))
              .join(', '),
      MedicineFrequency.once => medicine.onceDate == null
          ? l10n.freqOnce
          : '${l10n.freqOnce} — '
              '${AppDateUtils.dateLabel(medicine.onceDate!, locale)}',
    };
    return times.isEmpty ? freq : '$times · $freq';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final active = medicine.active;

    return AppListRow(
      onTap: onTap,
      title: medicine.name,
      titleColor: active ? null : theme.colorScheme.onSurfaceVariant,
      leading: AppIconBubble(
        icon: Icons.medication_rounded,
        color: active
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        background: active
            ? theme.colorScheme.primaryContainer
            : theme.palette.neutralContainer,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (medicine.doseLabel.isNotEmpty)
            Text(
              medicine.doseLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          Text(
            _scheduleSummary(l10n),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              AppPill(
                label: active ? l10n.medActive : l10n.medInactive,
                icon: active
                    ? Icons.check_circle_rounded
                    : Icons.pause_circle_filled_rounded,
                color: active
                    ? theme.palette.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (medicine.needsRefill && medicine.stockCount != null) ...[
                const SizedBox(width: AppSpacing.xs),
                AppPill(
                  label: l10n.medStockLeft(medicine.stockCount!),
                  icon: Icons.inventory_2_rounded,
                  color: theme.palette.warning,
                  background: theme.palette.warningContainer,
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: onMenu == null
          ? null
          : IconButton(
              onPressed: onMenu,
              tooltip: l10n.medEdit,
              icon: const Icon(Icons.more_vert_rounded),
              style: IconButton.styleFrom(
                minimumSize: const Size(AppSizes.tapTarget, AppSizes.tapTarget),
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

/// Lightweight daily summary: "4 of 5 medicines taken" with a thin bar.
/// Deliberately not an analytics widget.
class ProgressCard extends StatelessWidget {
  const ProgressCard({super.key, required this.stats});

  final AdherenceStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final total = stats.total;
    final taken = stats.taken;
    final ratio = total == 0 ? 0.0 : (taken / total).clamp(0.0, 1.0);
    final complete = total > 0 && taken == total;
    final barColor = complete ? theme.palette.success : theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                total == 0
                    ? l10n.homeEmptySchedule
                    : l10n.homeProgressOf(taken, total),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              '${(ratio * 100).round()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: barColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.pillRadius,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: AppMotion.slow,
            curve: Curves.easeOut,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 12,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ],
    );
  }
}
