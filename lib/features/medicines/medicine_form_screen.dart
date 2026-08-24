import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine.dart';
import '../../data/models/medicine_frequency.dart';
import '../../data/models/medicine_schedule.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/big_button.dart';

/// Add / edit medicine form. Designed for one-handed elderly use: large
/// fields, big chips, no hidden options.
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.medicine == null ? l10n.medAdd : l10n.medEdit),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _SectionLabel(l10n.medName),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(hintText: l10n.medNameHint),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.medName : null,
            ),
            const SizedBox(height: 20),
            _SectionLabel(l10n.medDose),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dose,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(hintText: l10n.medDoseHint),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _unit,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(hintText: l10n.medDoseUnitHint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final unit in _quickUnits(l10n))
                  ActionChip(
                    avatar: Icon(unit.icon, size: 20),
                    label: Text(unit.label, style: theme.textTheme.labelLarge),
                    onPressed: () => setState(() {
                      _unit.text = unit.value;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(l10n.medFoodInstruction),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final food in FoodInstruction.values)
                  ChoiceChip(
                    label: Text(_foodLabel(l10n, food)),
                    selected: _food == food,
                    onSelected: (_) => setState(() => _food = food),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(l10n.medFrequency),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _freqChip(l10n.freqEveryDay, MedicineFrequency.daily),
                _freqChip(
                  l10n.freqSpecificDays,
                  MedicineFrequency.specificDays,
                ),
                _freqChip(l10n.freqOnce, MedicineFrequency.once),
                _freqChip(l10n.freqMultiple, MedicineFrequency.multiple),
              ],
            ),
            if (_frequency == MedicineFrequency.specificDays) ...[
              const SizedBox(height: 20),
              _SectionLabel(l10n.medSelectDays),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.work_rounded, size: 20),
                    label: Text(
                      l10n.medPresetWeekdays,
                      style: theme.textTheme.labelLarge,
                    ),
                    onPressed: () => setState(() {
                      _selectedDays = [1, 2, 3, 4, 5];
                    }),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.weekend_rounded, size: 20),
                    label: Text(
                      l10n.medPresetWeekends,
                      style: theme.textTheme.labelLarge,
                    ),
                    onPressed: () => setState(() {
                      _selectedDays = [6, 7];
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var d = DateTime.monday; d <= DateTime.sunday; d++)
                    FilterChip(
                      label: Text(
                        AppDateUtils.weekdayShort(d, locale),
                        style: theme.textTheme.labelLarge,
                      ),
                      selected: _selectedDays.contains(d),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _selectedDays = {..._selectedDays, d}.toList()
                            ..sort();
                        } else {
                          _selectedDays.remove(d);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (_frequency == MedicineFrequency.once) ...[
              const SizedBox(height: 20),
              _SectionLabel(l10n.medOnceDate),
              BigButton(
                label: _onceDate == null
                    ? l10n.medOnceDate
                    : AppDateUtils.dateLabel(_onceDate!, locale),
                icon: Icons.calendar_month_rounded,
                height: 60,
                outlined: true,
                onPressed: _pickDate,
              ),
            ],
            const SizedBox(height: 20),
            _SectionLabel(l10n.medReminderTime),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _times.length; i++)
                  InputChip(
                    label: Text(
                      AppDateUtils.timeLabel(
                        DateTime(2024, 1, 1, _times[i].hour, _times[i].minute),
                        locale,
                      ),
                      style: theme.textTheme.labelLarge,
                    ),
                    avatar: const Icon(Icons.schedule_rounded, size: 22),
                    onPressed: () => _pickTime(i),
                    onDeleted: _times.length > 1
                        ? () => setState(() => _times.removeAt(i))
                        : null,
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 22),
                  label: Text(
                    l10n.medAddAnotherTime,
                    style: theme.textTheme.labelLarge,
                  ),
                  onPressed: _addTime,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionLabel(l10n.medQuickTimes),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in _timeSlots(l10n))
                  InputChip(
                    avatar: Icon(slot.icon, size: 22),
                    label: Text(slot.label, style: theme.textTheme.labelLarge),
                    selected: _times.any(
                      (t) =>
                          t.hour == slot.time.hour &&
                          t.minute == slot.time.minute,
                    ),
                    showCheckmark: false,
                    onPressed: () => setState(() => _toggleSlot(slot.time)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(l10n.medNotes),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              style: theme.textTheme.bodyLarge,
              decoration: InputDecoration(hintText: l10n.medNotes),
            ),
            const SizedBox(height: 20),
            _SectionLabel(l10n.medStockTracking),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCount,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(
                      hintText: l10n.medStockCountHint,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _refillAt,
                    keyboardType: TextInputType.number,
                    style: theme.textTheme.titleMedium,
                    decoration: InputDecoration(hintText: l10n.medRefillAtHint),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            BigButton(
              label: l10n.medSave,
              icon: Icons.save_rounded,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _freqChip(String label, MedicineFrequency frequency) {
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(label, style: theme.textTheme.labelLarge),
      selected: _frequency == frequency,
      onSelected: (_) => setState(() => _frequency = frequency),
    );
  }

  Future<void> _pickTime(int index) async {
    final l10n = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      helpText: l10n.medReminderTime,
      cancelText: l10n.btnCancel,
      confirmText: l10n.permOk,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _times[index] = picked);
    }
  }

  /// Toggles a quick time slot: adds it when absent, removes it when present.
  void _toggleSlot(TimeOfDay t) {
    final exists = _times.any((x) => x.hour == t.hour && x.minute == t.minute);
    if (exists) {
      _times.removeWhere((x) => x.hour == t.hour && x.minute == t.minute);
    } else {
      _times.add(t);
    }
    // Keep reminder times in chronological order.
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
      (
        label: l10n.medUnitSpoon,
        value: 'spoon',
        icon: Icons.restaurant_rounded,
      ),
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
        if (currentTimes.contains(key)) {
          if (!conflicts.contains(med.name)) conflicts.add(med.name);
        }
      }
    }
    return conflicts;
  }

  Future<void> _addTime() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: l10n.medReminderTime,
      cancelText: l10n.btnCancel,
      confirmText: l10n.permOk,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _times.add(picked));
    }
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
    );
    if (picked != null) {
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

    // Check for schedule conflicts with other medicines.
    if (!mounted) return;
    final appState = context.read<AppState>();
    final conflicts = _findConflicts(appState.medicines);
    if (conflicts.isNotEmpty && mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.medConflictTitle),
          content: Text(l10n.medConflictBody(conflicts.join(', '))),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.btnCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.medSave),
            ),
          ],
        ),
      );
      if (proceed != true) return;
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
    await context.read<AppState>().saveMedicine(medicine);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.medSaved)));
    Navigator.of(context).pop();
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
