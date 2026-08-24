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

/// Lists all medicines with search, pause/resume, edit and delete actions.
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final filtered = _query.isEmpty
        ? appState.medicines
        : appState.medicines
              .where(
                (m) => m.name.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();

    return Scaffold(
      body: SafeArea(
        child: appState.loading
            ? const Center(child: CircularProgressIndicator())
            : appState.medicines.isEmpty
            ? _EmptyState(l10n: l10n)
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                children: [
                  Text(l10n.medTitle, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          l10n.medSearchEmpty,
                          style: theme.textTheme.titleMedium,
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
              ),
      ),
      floatingActionButton: FloatingActionButton.large(
        tooltip: l10n.medAdd,
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add_rounded, size: 36),
      ),
    );
  }

  void _openForm(BuildContext context, {Medicine? medicine}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineFormScreen(medicine: medicine),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.medNoMedicines,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MedicineFormScreen(),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 28),
              label: Text(l10n.medAdd),
            ),
          ],
        ),
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

    return Card(
      color: medicine.active ? null : theme.colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    medicine.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: medicine.active
                          ? null
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                _StatusDot(active: medicine.active, l10n: l10n),
              ],
            ),
            if (medicine.doseLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(medicine.doseLabel, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 8),
            Text(
              _scheduleSummary(l10n, locale),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (medicine.foodInstruction != FoodInstruction.none) ...[
              const SizedBox(height: 2),
              Text(
                _foodLabel(l10n, medicine.foodInstruction),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: medicine.active ? l10n.medPause : l10n.medResume,
                  iconSize: 30,
                  icon: Icon(
                    medicine.active
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                  ),
                  onPressed: () => appState.setMedicineActive(
                    medicine.id!,
                    !medicine.active,
                  ),
                ),
                IconButton(
                  tooltip: l10n.medEdit,
                  iconSize: 30,
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MedicineFormScreen(medicine: medicine),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.medDelete,
                  iconSize: 30,
                  icon: Icon(Icons.delete_rounded, color: theme.missedColor),
                  onPressed: () => _confirmDelete(context, appState),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState) async {
    final l10n = AppLocalizations.of(context);
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
      MedicineFrequency.specificDays =>
        medicine.selectedDays.isEmpty
            ? l10n.freqSpecificDays
            : medicine.selectedDays
                  .map((d) => AppDateUtils.weekdayShort(d, locale))
                  .join(', '),
      MedicineFrequency.once =>
        medicine.onceDate == null
            ? l10n.freqOnce
            : '${l10n.freqOnce} — '
                  '${AppDateUtils.dateLabel(medicine.onceDate!, locale)}',
    };
    return '$times · $freq';
  }

  String _foodLabel(AppLocalizations l10n, FoodInstruction food) {
    return switch (food) {
      FoodInstruction.none => '',
      FoodInstruction.before => l10n.foodBefore,
      FoodInstruction.after => l10n.foodAfter,
      FoodInstruction.withFood => l10n.foodWith,
    };
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.active, required this.l10n});

  final bool active;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = active ? theme.successColor : theme.colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            active ? l10n.medActive : l10n.medInactive,
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
