import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/food_instruction.dart';
import 'app_buttons.dart';

/// The single most important block in the app: what to take, and one obvious
/// way to say "I have taken it".
///
/// Visual weight is reserved for the primary action — Snooze and Skip are real
/// but deliberately quieter, so a hurried or confused user is not choosing
/// between three equally loud buttons.
class NextMedicineCard extends StatefulWidget {
  const NextMedicineCard({
    super.key,
    required this.entry,
    required this.grace,
    required this.locale,
    required this.snoozeMinutes,
    required this.onTake,
    required this.onSkip,
    this.onSnooze,
    this.onSpeak,
  });

  final DoseEntry entry;
  final Duration grace;
  final String locale;
  final int snoozeMinutes;
  final VoidCallback onTake;
  final VoidCallback onSkip;
  final VoidCallback? onSnooze;
  final VoidCallback? onSpeak;

  @override
  State<NextMedicineCard> createState() => _NextMedicineCardState();
}

class _NextMedicineCardState extends State<NextMedicineCard> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Keeps the "in 20 minutes" line honest without visible per-second motion.
    _ticker = Timer.periodic(
      const Duration(seconds: 20),
      (_) => mounted ? setState(() => _now = DateTime.now()) : null,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _when(AppLocalizations l10n) {
    final entry = widget.entry;
    final due = _effectiveTime(entry);
    final diff = due.difference(_now);
    if (diff.isNegative) {
      final late = _now.difference(due);
      return late.inMinutes < 60
          ? l10n.homeOverdueMin(late.inMinutes)
          : l10n.homeOverdueHours(late.inHours);
    }
    if (diff.inMinutes <= 10) return l10n.homeDueNow;
    if (diff.inMinutes < 60) return l10n.homeInMin(diff.inMinutes);
    if (diff.inHours < 24) return l10n.homeInHours(diff.inHours);
    return l10n.homeInDays(diff.inDays);
  }

  DateTime _effectiveTime(DoseEntry entry) {
    final snoozed = entry.dose.snoozedUntil;
    if (snoozed != null && snoozed.isAfter(_now)) return snoozed;
    return entry.dose.scheduledAt;
  }

  String _food(AppLocalizations l10n, FoodInstruction food) => switch (food) {
    FoodInstruction.none => '',
    FoodInstruction.before => l10n.foodBefore,
    FoodInstruction.after => l10n.foodAfter,
    FoodInstruction.withFood => l10n.foodWith,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final entry = widget.entry;
    final medicine = entry.medicine;
    final due = _effectiveTime(entry);
    final isDue = !due.isAfter(_now.add(const Duration(minutes: 10)));
    final isSnoozed =
        entry.dose.snoozedUntil != null && entry.dose.snoozedUntil!.isAfter(_now);
    final overdue = due.isBefore(_now);
    final food = _food(l10n, medicine.foodInstruction);

    // "Due now" is the only state allowed to shout: red tint + red border,
    // paired with an icon and an explicit word so colour is never the only cue.
    final surface = isDue
        ? theme.colorScheme.errorContainer
        : theme.palette.heroSurface;
    final border = isDue ? theme.missedColor : theme.palette.heroBorder;
    final accent = isDue ? theme.missedColor : theme.colorScheme.primary;

    return AnimatedContainer(
      duration: AppMotion.normal,
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadius.sheetRadius,
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDue
                      ? Icons.notifications_active_rounded
                      : Icons.medication_rounded,
                  size: AppSizes.iconLg,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  l10n.homeNextMedicine.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accent,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.onSpeak != null)
                IconButton(
                  onPressed: widget.onSpeak,
                  tooltip: l10n.speakReminder,
                  icon: Icon(Icons.volume_up_rounded, color: accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          Text(
            medicine.name,
            style: theme.textTheme.headlineLarge?.copyWith(height: 1.15),
          ),

          if (medicine.doseLabel.isNotEmpty || food.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              [medicine.doseLabel, food].where((s) => s.isNotEmpty).join(' · '),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                AppDateUtils.timeLabel(due, widget.locale),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      overdue
                          ? Icons.error_outline_rounded
                          : Icons.timelapse_rounded,
                      size: AppSizes.iconSm,
                      color: accent,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      _when(l10n),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (isSnoozed) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.homeSnoozedUntil(
                AppDateUtils.timeLabel(entry.dose.snoozedUntil!, widget.locale),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],

          const SizedBox(height: AppSpacing.lg),

          // ── The one action that matters ─────────────────────────────────
          AppButton(
            label: l10n.homeTakeMedicine,
            icon: Icons.check_rounded,
            height: AppSizes.heroButton,
            onPressed: widget.onTake,
          ),

          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (widget.onSnooze != null)
                Expanded(
                  child: AppButton.secondary(
                    label: l10n.notifActionSnooze(widget.snoozeMinutes),
                    icon: Icons.snooze_rounded,
                    height: 52,
                    onPressed: widget.onSnooze,
                  ),
                ),
              if (widget.onSnooze != null) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: AppButton.quiet(
                  label: l10n.homeSkip,
                  icon: Icons.close_rounded,
                  height: 52,
                  onPressed: widget.onSkip,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
