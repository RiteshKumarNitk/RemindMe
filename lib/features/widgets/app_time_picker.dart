import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import 'app_buttons.dart';

/// Large, obvious time picker.
///
/// Replaces the small native Material clock/dial for the app's main user: two
/// big, comfortably scrollable wheels, a 12-hour read-out in display type and
/// one obvious "Confirm time" button.
Future<TimeOfDay?> showAppTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
  String? title,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _TimePickerSheet(initial: initial, title: title),
  );
}

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.initial, this.title});

  final TimeOfDay initial;
  final String? title;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late int _hour12; // 1..12
  late int _minute; // 0..59
  late bool _pm;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  static const double _itemExtent = 56;
  static const double _wheelHeight = 190;

  @override
  void initState() {
    super.initState();
    final h = widget.initial.hour;
    _pm = h >= 12;
    _hour12 = h % 12 == 0 ? 12 : h % 12;
    _minute = widget.initial.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  TimeOfDay get _time {
    var h = _hour12 % 12;
    if (_pm) h += 12;
    return TimeOfDay(hour: h, minute: _minute);
  }

  String _label() {
    final h = _hour12.toString();
    final m = _minute.toString().padLeft(2, '0');
    return '$h:$m ${_pm ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title ?? l10n.medReminderTime,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),

            // Read-out: what the wheels currently mean, in large type.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: AppRadius.controlRadius,
              ),
              child: Text(
                _label(),
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Row(
              children: [
                Expanded(
                  child: _Wheel(
                    controller: _hourController,
                    height: _wheelHeight,
                    itemExtent: _itemExtent,
                    count: 12,
                    labelOf: (i) => '${i + 1}',
                    onChanged: (i) => setState(() => _hour12 = i + 1),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(':', style: theme.textTheme.displaySmall),
                ),
                Expanded(
                  child: _Wheel(
                    controller: _minuteController,
                    height: _wheelHeight,
                    itemExtent: _itemExtent,
                    count: 60,
                    labelOf: (i) => i.toString().padLeft(2, '0'),
                    onChanged: (i) => setState(() => _minute = i),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _MeridiemColumn(
                  isPm: _pm,
                  onChanged: (pm) => setState(() => _pm = pm),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            AppButton(
              label: l10n.medConfirmTime,
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(_time),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.controller,
    required this.height,
    required this.itemExtent,
    required this.count,
    required this.labelOf,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final double height;
  final double itemExtent;
  final int count;
  final String Function(int) labelOf;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.controlRadius,
        border: Border.all(color: theme.cardBorder, width: 1.5),
      ),
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: itemExtent,
        physics: const FixedExtentScrollPhysics(),
        perspective: 0.001,
        overAndUnderCenterOpacity: 0.45,
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) => Center(
            child: Text(
              labelOf(index),
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeridiemColumn extends StatelessWidget {
  const _MeridiemColumn({required this.isPm, required this.onChanged});

  final bool isPm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget option(String label, bool pm) {
      final selected = isPm == pm;
      return Expanded(
        child: Material(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.controlRadius,
          child: InkWell(
            onTap: () => onChanged(pm),
            borderRadius: AppRadius.controlRadius,
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 190,
      width: 76,
      child: Column(
        children: [
          option('AM', false),
          const SizedBox(height: AppSpacing.xs),
          option('PM', true),
        ],
      ),
    );
  }
}
