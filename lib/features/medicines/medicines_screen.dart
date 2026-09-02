import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/medicine_frequency.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import 'medicine_form_screen.dart';

/// Lists all medicines with search, pause/resume, edit and delete actions,
/// styled to the DoseWise design language.
class MedicinesScreen extends StatefulWidget {
  const MedicinesScreen({super.key});

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openForm({Medicine? medicine}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineFormScreen(medicine: medicine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final all = appState.medicines;
    final filtered = _query.isEmpty
        ? all
        : all
            .where((m) => m.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();
    final activeCount = all.where((m) => m.active).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: appState.loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  MediaQuery.paddingOf(context).bottom + 108,
                ),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.medTitle,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton.filled(
                        tooltip: l10n.medAdd,
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.add_rounded),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(44, 44),
                        ),
                      ),
                    ],
                  ),
                  if (all.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      l10n.medActiveCount(activeCount, all.length),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  if (all.isEmpty)
                    _EmptyState(onAdd: () => _openForm())
                  else ...[
                    TextField(
                      controller: _searchController,
                      style: theme.textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: l10n.medSearch,
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            l10n.medSearchEmpty,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final med in filtered)
                        _MedicineCard(
                          medicine: med,
                          locale: settings.settings.locale,
                        ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Icon(
              Icons.medication_rounded,
              size: 50,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.medNoMedicines,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 26),
            label: Text(l10n.medAdd),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  const _MedicineCard({required this.medicine, required this.locale});

  final Medicine medicine;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final active = medicine.active;
    final food = _foodLabel(l10n, medicine.foodInstruction);
    final subColor = theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: active
            ? theme.colorScheme.surface
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (active
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    size: 22,
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: active ? null : subColor,
                        ),
                      ),
                      if (medicine.doseLabel.isNotEmpty || food.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [
                              if (medicine.doseLabel.isNotEmpty)
                                medicine.doseLabel,
                              if (food.isNotEmpty) food,
                            ].join('  •  '),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: subColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusPill(active: active, l10n: l10n),
              ],
            ),
            const SizedBox(height: 12),
            _IconLine(
              icon: Icons.schedule_rounded,
              text: _scheduleSummary(l10n, locale),
            ),
            if (medicine.hasStockTracking && medicine.stockCount != null) ...[
              const SizedBox(height: 6),
              _IconLine(
                icon: Icons.inventory_2_rounded,
                text: l10n.medStockLeft(medicine.stockCount!),
                color: medicine.needsRefill ? theme.missedColor : null,
              ),
            ],
            if (medicine.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              _IconLine(
                icon: Icons.sticky_note_2_rounded,
                text: medicine.notes.trim(),
                maxLines: 3,
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                _CardAction(
                  icon: active
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  label: active ? l10n.medPause : l10n.medResume,
                  onTap: () =>
                      appState.setMedicineActive(medicine.id!, !active),
                ),
                _CardAction(
                  icon: Icons.edit_rounded,
                  label: l10n.medEdit,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MedicineFormScreen(medicine: medicine),
                    ),
                  ),
                ),
                _CardAction(
                  icon: Icons.delete_outline_rounded,
                  label: l10n.medDelete,
                  danger: true,
                  onTap: () => _confirmDelete(context, appState, l10n),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AppState appState,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.medDeleteTitle),
        content: Text(l10n.medDeleteBody(medicine.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).missedColor,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.medDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.deleteMedicine(medicine.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.medDeleted)));
      }
    }
  }

  String _scheduleSummary(AppLocalizations l10n, String locale) {
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
    return times.isEmpty ? freq : '$times  ·  $freq';
  }

  String _foodLabel(AppLocalizations l10n, FoodInstruction food) => switch (food) {
    FoodInstruction.none => '',
    FoodInstruction.before => l10n.foodBefore,
    FoodInstruction.after => l10n.foodAfter,
    FoodInstruction.withFood => l10n.foodWith,
  };
}

class _IconLine extends StatelessWidget {
  const _IconLine({
    required this.icon,
    required this.text,
    this.color,
    this.maxLines = 2,
  });

  final IconData icon;
  final String text;
  final Color? color;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: c),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: c),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active, required this.l10n});

  final bool active;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.successColor : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        active ? l10n.medActive : l10n.medInactive,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? theme.missedColor : theme.colorScheme.primary;
    return Expanded(
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: color),
        label: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          minimumSize: const Size(0, 44),
        ),
      ),
    );
  }
}
