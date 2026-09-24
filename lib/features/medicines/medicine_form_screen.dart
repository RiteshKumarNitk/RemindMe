import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/medicine_frequency.dart';
import '../../data/models/medicine_schedule.dart';
import '../../services/interaction_checker.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/app_time_picker.dart';

/// Add / edit a medicine.
///
/// Ordered the way a person would say it out loud — *what*, *how much*, *when*,
/// *how often* — with optional extras tucked at the end. One screen, no wizard,
/// but grouped into blocks so it never reads as one giant form. The save button
/// stays pinned to the bottom so it is always reachable.
class MedicineFormScreen extends StatefulWidget {
  const MedicineFormScreen({super.key, this.medicine});

  final Medicine? medicine;

  @override
  State<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends State<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _unit;
  late final TextEditingController _notes;
  late final TextEditingController _stockCount;
  late final TextEditingController _refillAt;
  late MedicineFrequency _frequency;
  late FoodInstruction _food;
  late List<int> _selectedDays;
  DateTime? _onceDate;
  late List<TimeOfDay> _times;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.medicine;
    _name = TextEditingController(text: m?.name ?? '');
    _dose = TextEditingController(text: m?.dosage ?? '');
    _unit = TextEditingController(text: m?.dosageUnit ?? '');
    _notes = TextEditingController(text: m?.notes ?? '');
    _stockCount = TextEditingController(text: m?.stockCount?.toString() ?? '');
    _refillAt = TextEditingController(text: m?.refillAt?.toString() ?? '');
    _frequency = m?.frequency ?? MedicineFrequency.daily;
    _food = m?.foodInstruction ?? FoodInstruction.none;
    _selectedDays = [...?m?.selectedDays];
    _onceDate = m?.onceDate;
    _times = [for (final s in (m?.schedules ?? const [])) s.time];
    if (_times.isEmpty) _times = [const TimeOfDay(hour: 8, minute: 0)];
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _unit.dispose();
    _notes.dispose();
    _stockCount.dispose();
    _refillAt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = context.watch<SettingsController>().settings.locale;
    final isEdit = widget.medicine != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? l10n.medEdit : l10n.medAdd),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l10n.btnCancel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            // ── What is it ────────────────────────────────────────────────
            _FieldLabel(l10n.medName),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(hintText: l10n.medNameHint),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.medName : null,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── How much ──────────────────────────────────────────────────
            _FieldLabel(l10n.medDose),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dose,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                    decoration: InputDecoration(hintText: l10n.medDoseHint),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _unit,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: l10n.medDoseUnitHint,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final unit in _quickUnits(l10n))
                  ActionChip(
                    avatar: Icon(unit.icon, size: AppSizes.iconSm),
                    label: Text(unit.label),
                    onPressed: () => setState(() => _unit.text = unit.value),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── When ──────────────────────────────────────────────────────
            _FieldLabel(l10n.medReminderTime),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (var i = 0; i < _times.length; i++)
                  InputChip(
                    avatar: const Icon(
                      Icons.schedule_rounded,
                      size: AppSizes.iconMd,
                    ),
                    label: Text(
                      AppDateUtils.timeLabel(
                        DateTime(
                          2024,
                          1,
                          1,
                          _times[i].hour,
                          _times[i].minute,
                        ),
                        locale,
                      ),
                      style: theme.textTheme.labelLarge,
                    ),
                    onPressed: () => _pickTime(i),
                    onDeleted: _times.length > 1
                        ? () => setState(() => _times.removeAt(i))
                        : null,
                    deleteButtonTooltipMessage: l10n.medDelete,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: l10n.medAddAnotherTime,
                    icon: Icons.add_rounded,
                    height: 52,
                    onPressed: _addTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            _FieldLabel(l10n.medQuickTimes),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final slot in _timeSlots(l10n))
                  FilterChip(
                    showCheckmark: false,
                    avatar: Icon(
                      slot.icon,
                      size: AppSizes.iconMd,
                      color: _hasTime(slot.time)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    label: Text(slot.label),
                    selected: _hasTime(slot.time),
                    onSelected: (_) => setState(() => _toggleSlot(slot.time)),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── How often ─────────────────────────────────────────────────
            _FieldLabel(l10n.medFrequency),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _freqChip(l10n.freqEveryDay, MedicineFrequency.daily),
                _freqChip(l10n.freqSpecificDays, MedicineFrequency.specificDays),
                _freqChip(l10n.freqOnce, MedicineFrequency.once),
                _freqChip(l10n.freqMultiple, MedicineFrequency.multiple),
              ],
            ),

            if (_frequency == MedicineFrequency.specificDays) ...[
              const SizedBox(height: AppSpacing.lg),
              _FieldLabel(l10n.medSelectDays),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                    FilterChip(
                      showCheckmark: false,
                      label: Text(AppDateUtils.weekdayShort(d, locale)),
                      selected: _selectedDays.contains(d),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _selectedDays = {..._selectedDays, d}.toList()..sort();
                        } else {
                          _selectedDays.remove(d);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: l10n.medPresetWeekdays,
                      icon: Icons.work_rounded,
                      height: 52,
                      onPressed: () =>
                          setState(() => _selectedDays = [1, 2, 3, 4, 5]),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: AppButton.secondary(
                      label: l10n.medPresetWeekends,
                      icon: Icons.weekend_rounded,
                      height: 52,
                      onPressed: () => setState(() => _selectedDays = [6, 7]),
                    ),
                  ),
                ],
              ),
            ],

            if (_frequency == MedicineFrequency.once) ...[
              const SizedBox(height: AppSpacing.lg),
              _FieldLabel(l10n.medOnceDate),
              AppButton.secondary(
                label: _onceDate == null
                    ? l10n.medOnceDate
                    : AppDateUtils.dateLabel(_onceDate!, locale),
                icon: Icons.calendar_month_rounded,
                onPressed: _pickDate,
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),
            AppSectionHeader(
              title: l10n.medOptional,
              subtitle: l10n.medNotes,
            ),

            const SizedBox(height: AppSpacing.md),
            _FieldLabel(l10n.medFoodInstruction),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final food in FoodInstruction.values)
                  ChoiceChip(
                    label: Text(_foodLabel(l10n, food)),
                    selected: _food == food,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _food = food),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            _FieldLabel(l10n.medNotes),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(hintText: l10n.medNotes),
            ),

            const SizedBox(height: AppSpacing.lg),
            _FieldLabel(l10n.medStockTracking),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCount,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: l10n.medStockCountHint,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _refillAt,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: l10n.medRefillAtHint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: AppButton(
          label: l10n.medSave,
          icon: Icons.check_rounded,
          busy: _saving,
          onPressed: _saving ? null : _save,
        ),
      ),
    );
  }

  Widget _freqChip(String label, MedicineFrequency frequency) {
    return ChoiceChip(
      label: Text(label),
      showCheckmark: false,
      selected: _frequency == frequency,
      onSelected: (_) => setState(() => _frequency = frequency),
    );
  }

  bool _hasTime(TimeOfDay t) =>
      _times.any((x) => x.hour == t.hour && x.minute == t.minute);

  Future<void> _pickTime(int index) async {
    final picked = await showAppTimePicker(
      context,
      initial: _times[index],
      title: AppLocalizations.of(context).medReminderTime,
    );
    if (picked != null && mounted) {
      setState(() => _times[index] = picked);
    }
  }

  Future<void> _addTime() async {
    final picked = await showAppTimePicker(
      context,
      initial: const TimeOfDay(hour: 8, minute: 0),
      title: AppLocalizations.of(context).medReminderTime,
    );
    if (picked != null && mounted) {
      setState(() => _times = [..._times, picked]);
    }
  }

  /// Toggles a quick time slot: adds it when absent, removes it when present.
  void _toggleSlot(TimeOfDay t) {
    if (_hasTime(t)) {
      _times.removeWhere((x) => x.hour == t.hour && x.minute == t.minute);
    } else {
      _times.add(t);
    }
    _times.sort((a, b) {
      final c = a.hour.compareTo(b.hour);
      return c != 0 ? c : a.minute.compareTo(b.minute);
    });
  }

  /// Quick-pick unit options that fill the unit field in one tap.
  List<({String label, String value, IconData icon})> _quickUnits(
    AppLocalizations l10n,
  ) {
    return [
      (label: l10n.medUnitMg, value: 'mg', icon: Icons.scale_rounded),
      (label: l10n.medUnitMl, value: 'ml', icon: Icons.water_drop_rounded),
      (
        label: l10n.medUnitTablet,
        value: 'tablet',
        icon: Icons.medication_rounded,
      ),
      (
        label: l10n.medUnitCapsule,
        value: 'capsule',
        icon: Icons.medication_liquid_rounded,
      ),
      (label: l10n.medUnitDrop, value: 'drop', icon: Icons.grain_rounded),
      (label: l10n.medUnitSpoon, value: 'spoon', icon: Icons.restaurant_rounded),
    ];
  }

  /// One-tap time slots for common dosing windows.
  List<({String label, TimeOfDay time, IconData icon})> _timeSlots(
    AppLocalizations l10n,
  ) {
    return [
      (
        label: l10n.medTimeSlotMorning,
        time: const TimeOfDay(hour: 8, minute: 0),
        icon: Icons.wb_sunny_rounded,
      ),
      (
        label: l10n.medTimeSlotAfternoon,
        time: const TimeOfDay(hour: 13, minute: 0),
        icon: Icons.light_mode_rounded,
      ),
      (
        label: l10n.medTimeSlotEvening,
        time: const TimeOfDay(hour: 18, minute: 0),
        icon: Icons.wb_twilight_rounded,
      ),
      (
        label: l10n.medTimeSlotNight,
        time: const TimeOfDay(hour: 21, minute: 0),
        icon: Icons.nights_stay_rounded,
      ),
    ];
  }

  /// Returns names of other medicines that share any of the current times.
  List<String> _findConflicts(List<Medicine> allMedicines) {
    final currentTimes = _times
        .map((t) => '${t.hour}:${t.minute.toString().padLeft(2, '0')}')
        .toSet();
    final conflicts = <String>[];
    for (final med in allMedicines) {
      if (med.id == widget.medicine?.id) continue;
      for (final s in med.schedules) {
        final key = '${s.hour}:${s.minute.toString().padLeft(2, '0')}';
        if (currentTimes.contains(key) && !conflicts.contains(med.name)) {
          conflicts.add(med.name);
        }
      }
    }
    return conflicts;
  }

  Future<void> _pickDate() async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _onceDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      helpText: l10n.medOnceDate,
      cancelText: l10n.btnCancel,
      confirmText: l10n.permOk,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: DatePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.sheetRadius,
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _onceDate = picked);
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_times.isEmpty) {
      _showMessage(l10n.medReminderTime);
      return;
    }
    if (_frequency == MedicineFrequency.once && _onceDate == null) {
      _showMessage(l10n.medOnceDate);
      return;
    }
    if (_frequency == MedicineFrequency.specificDays && _selectedDays.isEmpty) {
      _showMessage(l10n.medSelectDays);
      return;
    }

    if (!mounted) return;
    final appState = context.read<AppState>();

    // Schedule conflict warning (another medicine at the same time).
    final conflicts = _findConflicts(appState.medicines);
    if (conflicts.isNotEmpty && mounted) {
      final proceed = await showAppConfirmDialog(
        context,
        title: l10n.medConflictTitle,
        message: l10n.medConflictBody(conflicts.join(', ')),
        confirmLabel: l10n.medSave,
        cancelLabel: l10n.btnCancel,
        destructive: false,
        icon: Icons.schedule_rounded,
      );
      if (!proceed) return;
    }

    // Drug interaction warning.
    final otherMeds = appState.medicines
        .where((m) => m.id != widget.medicine?.id)
        .map((m) => m.name)
        .toList();
    final interactions = InteractionChecker.checkNewMedicine(
      _name.text.trim(),
      otherMeds,
    );
    if (interactions.isNotEmpty && mounted) {
      final proceed = await _confirmInteractions(interactions, l10n);
      if (!proceed) return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final medicine = Medicine(
      id: widget.medicine?.id,
      name: _name.text.trim(),
      dosage: _dose.text.trim(),
      dosageUnit: _unit.text.trim(),
      notes: _notes.text.trim(),
      foodInstruction: _food,
      frequency: _frequency,
      selectedDays: _selectedDays,
      onceDate: _onceDate,
      active: widget.medicine?.active ?? true,
      stockCount: int.tryParse(_stockCount.text.trim()),
      refillAt: int.tryParse(_refillAt.text.trim()),
      createdAt: widget.medicine?.createdAt ?? now,
      updatedAt: now,
      schedules: [
        for (final t in _times)
          MedicineSchedule(
            medicineId: widget.medicine?.id ?? 0,
            hour: t.hour,
            minute: t.minute,
          ),
      ],
    );

    if (!mounted) return;
    await appState.saveMedicine(medicine);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.medSaved)));
    Navigator.of(context).pop();
  }

  Future<bool> _confirmInteractions(
    List<InteractionWarning> interactions,
    AppLocalizations l10n,
  ) async {
    final theme = Theme.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: theme.palette.warning,
          size: AppSizes.iconXl,
        ),
        title: const Text('Drug interaction warning'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in interactions) ...[
              Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: w.severity == InteractionSeverity.high
                      ? theme.colorScheme.errorContainer
                      : theme.palette.warningContainer,
                  borderRadius: AppRadius.controlRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${w.medicine1} + ${w.medicine2}',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(w.warning, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Please consult your doctor before saving.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          AppButton.secondary(
            label: l10n.btnCancel,
            height: 52,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppButton(
            label: l10n.medSave,
            height: 52,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceBetween,
      ),
    );
    return result ?? false;
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _foodLabel(AppLocalizations l10n, FoodInstruction food) {
    return switch (food) {
      FoodInstruction.none => l10n.foodNone,
      FoodInstruction.before => l10n.foodBefore,
      FoodInstruction.after => l10n.foodAfter,
      FoodInstruction.withFood => l10n.foodWith,
    };
  }
}

/// Section label above a field or a group of chips.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
