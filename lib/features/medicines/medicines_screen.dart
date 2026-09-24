import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/medicine.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/medicine_tiles.dart';
import 'medicine_details_screen.dart';
import 'medicine_form_screen.dart';

/// "My medicines": the full list, searchable, one calm row per medicine.
///
/// Per-medicine actions (edit / pause / duplicate / delete) live behind the
/// row's menu instead of four visible buttons, so the list stays readable and
/// every action keeps a large tap target.
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

  void _openDetails(Medicine medicine) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MedicineDetailsScreen(medicine: medicine),
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
              .where(
                (m) => m.name.toLowerCase().contains(_query.toLowerCase()),
              )
              .toList();
    final activeCount = all.where((m) => m.active).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + 120,
        ),
        children: [
          AppPageHeader(
            title: l10n.medTitle,
            subtitle: all.isEmpty
                ? null
                : l10n.medActiveCount(activeCount, all.length),
            trailing: [
              AppIconButton(
                icon: Icons.add_rounded,
                semanticLabel: l10n.medAdd,
                onPressed: () => _openForm(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          if (appState.loading)
            const SkeletonList(padding: EdgeInsets.zero, rows: 3)
          else if (all.isEmpty)
            EmptyState(
              icon: Icons.medication_rounded,
              title: l10n.medNoMedicines,
              message: l10n.homeEmptyBody,
              actionLabel: l10n.medAdd,
              onAction: () => _openForm(),
            )
          else ...[
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.medSearch,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.medSearchClear,
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.md),

            if (filtered.isEmpty)
              EmptyState(
                compact: true,
                icon: Icons.search_off_rounded,
                title: l10n.medSearchEmpty,
                message: l10n.medSearch,
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < filtered.length; i++) ...[
                      MedicineSummaryTile(
                        medicine: filtered[i],
                        locale: settings.settings.locale,
                        onTap: () => _openDetails(filtered[i]),
                        onMenu: () => _openActions(filtered[i]),
                      ),
                      if (i != filtered.length - 1)
                        const AppDivider(indent: AppSpacing.md + AppSizes.avatar + AppSpacing.sm),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xl),
            AppButton.secondary(
              label: l10n.medAdd,
              icon: Icons.add_rounded,
              onPressed: () => _openForm(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.aboutBody,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openActions(Medicine medicine) async {
    final appState = context.read<AppState>();
    final l10n = AppLocalizations.of(context);
    final active = medicine.active;

    await showAppActionSheet(
      context,
      title: medicine.name,
      subtitle: medicine.doseLabel.isEmpty ? null : medicine.doseLabel,
      actions: [
        AppSheetAction(
          label: l10n.medEdit,
          icon: Icons.edit_rounded,
          onSelected: () => _openForm(medicine: medicine),
        ),
        AppSheetAction(
          label: active ? l10n.medPause : l10n.medResume,
          icon: active ? Icons.pause_rounded : Icons.play_arrow_rounded,
          onSelected: () async {
            await appState.setMedicineActive(medicine.id!, !active);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(active ? l10n.medPausedMsg : l10n.medResumedMsg),
              ),
            );
          },
        ),
        AppSheetAction(
          label: l10n.medDuplicate,
          subtitle: l10n.medDuplicateHint,
          icon: Icons.copy_rounded,
          onSelected: () => _duplicate(medicine, appState, l10n),
        ),
        AppSheetAction(
          label: l10n.medDelete,
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onSelected: () => _confirmDelete(medicine, appState, l10n),
        ),
      ],
    );
  }

  Future<void> _duplicate(
    Medicine medicine,
    AppState appState,
    AppLocalizations l10n,
  ) async {
    final now = DateTime.now();
    final copy = Medicine(
      name: '${medicine.name} (copy)',
      dosage: medicine.dosage,
      dosageUnit: medicine.dosageUnit,
      notes: medicine.notes,
      foodInstruction: medicine.foodInstruction,
      frequency: medicine.frequency,
      selectedDays: medicine.selectedDays,
      onceDate: medicine.onceDate,
      active: true,
      stockCount: medicine.stockCount,
      refillAt: medicine.refillAt,
      createdAt: now,
      updatedAt: now,
      schedules: medicine.schedules,
    );
    await appState.saveMedicine(copy);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.medSaved)));
  }

  Future<void> _confirmDelete(
    Medicine medicine,
    AppState appState,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.medDeleteTitle,
      message: l10n.medDeleteBody(medicine.name),
      confirmLabel: l10n.medDelete,
      cancelLabel: l10n.btnCancel,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed) return;
    await appState.deleteMedicine(medicine.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.medDeleted)));
  }
}
