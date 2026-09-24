import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/medicine_frequency.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_status.dart';
import '../widgets/app_surfaces.dart';
import 'medicine_form_screen.dart';

/// Everything the user told us about one medicine, plus the two things they
/// might want to do about it. Destructive actions live at the bottom, behind a
/// confirmation, and never next to the everyday actions.
class MedicineDetailsScreen extends StatelessWidget {
  const MedicineDetailsScreen({super.key, required this.medicine});

  final Medicine medicine;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = context.watch<SettingsController>().settings.locale;

    // Re-read from state so edits made from this screen show up immediately.
    final med = appState.medicines.firstWhere(
      (m) => m.id == medicine.id,
      orElse: () => medicine,
    );
    final active = med.active;

    return AppPage(
      title: l10n.medDetailsTitle,
      children: [
        Text(med.name, style: theme.textTheme.headlineMedium),
        if (med.doseLabel.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            med.doseLabel,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        AppPill(
          label: active ? l10n.medActive : l10n.medInactive,
          icon: active
              ? Icons.check_circle_rounded
              : Icons.pause_circle_filled_rounded,
          color: active
              ? theme.palette.success
              : theme.colorScheme.onSurfaceVariant,
        ),

        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: l10n.medReminderTime,
                value: _times(l10n, locale),
              ),
              const AppDivider(indent: AppSpacing.xxl + AppSpacing.md),
              _DetailRow(
                icon: Icons.repeat_rounded,
                label: l10n.medFrequency,
                value: _frequency(l10n, locale),
              ),
              const AppDivider(indent: AppSpacing.xxl + AppSpacing.md),
              _DetailRow(
                icon: Icons.restaurant_rounded,
                label: l10n.medFoodInstruction,
                value: _food(l10n, med.foodInstruction),
              ),
              if (med.notes.trim().isNotEmpty) ...[
                const AppDivider(indent: AppSpacing.xxl + AppSpacing.md),
                _DetailRow(
                  icon: Icons.notes_rounded,
                  label: l10n.medNotes,
                  value: med.notes.trim(),
                ),
              ],
              if (med.hasStockTracking && med.stockCount != null) ...[
                const AppDivider(indent: AppSpacing.xxl + AppSpacing.md),
                _DetailRow(
                  icon: Icons.inventory_2_rounded,
                  label: l10n.medStockTracking,
                  value: l10n.medStockLeft(med.stockCount!),
                  valueColor: med.needsRefill ? theme.palette.warning : null,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: l10n.medEdit,
          icon: Icons.edit_rounded,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MedicineFormScreen(medicine: med),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton.secondary(
          label: active ? l10n.medPause : l10n.medResume,
          icon: active ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onPressed: () async {
            await appState.setMedicineActive(med.id!, !active);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(active ? l10n.medPausedMsg : l10n.medResumedMsg),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: l10n.medDelete,
          icon: Icons.delete_outline_rounded,
          tone: AppButtonTone.danger,
          onPressed: () => _confirmDelete(context, appState, med, l10n),
        ),

        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.aboutBody,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AppState appState,
    Medicine med,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.medDeleteTitle,
      message: l10n.medDeleteBody(med.name),
      confirmLabel: l10n.medDelete,
      cancelLabel: l10n.btnCancel,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    await appState.deleteMedicine(med.id!);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.medDeleted)));
    Navigator.of(context).maybePop();
  }

  String _times(AppLocalizations l10n, String locale) {
    if (medicine.schedules.isEmpty) return l10n.profileNotSet;
    return medicine.schedules
        .map(
          (s) => AppDateUtils.timeLabel(
            DateTime(2024, 1, 1, s.hour, s.minute),
            locale,
          ),
        )
        .join('  ·  ');
  }

  String _frequency(AppLocalizations l10n, String locale) {
    return switch (medicine.frequency) {
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
  }

  String _food(AppLocalizations l10n, FoodInstruction food) => switch (food) {
    FoodInstruction.none => l10n.foodNone,
    FoodInstruction.before => l10n.foodBefore,
    FoodInstruction.after => l10n.foodAfter,
    FoodInstruction.withFood => l10n.foodWith,
  };
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: theme.colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: valueColor,
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
