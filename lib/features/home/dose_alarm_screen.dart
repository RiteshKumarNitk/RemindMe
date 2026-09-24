import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine_frequency.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_surfaces.dart';

/// Shown when a dose is due right now (and on lock-screen tap-through).
///
/// It looks like the rest of DoseWise — not a separate alarm app — but the
/// hierarchy is unmistakable: the medicine, then one huge TAKEN button. Snooze
/// and Skip are real options, deliberately quieter, so a confused user is not
/// choosing between three equally loud buttons.
class DoseAlarmScreen extends StatefulWidget {
  const DoseAlarmScreen({super.key, required this.entry});

  final DoseEntry entry;

  @override
  State<DoseAlarmScreen> createState() => _DoseAlarmScreenState();
}

class _DoseAlarmScreenState extends State<DoseAlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  DateTime _now = DateTime.now();
  Timer? _clock;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Safety net: never trap the user on this screen.
    _autoDismiss = Timer(const Duration(minutes: 5), () {
      if (mounted) Navigator.of(context).maybePop();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _autoSpeak();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _autoDismiss?.cancel();
    _pulse.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _autoSpeak() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsController>();
      if (!settings.voiceEnabled) return;
      _speak(settings);
    });
  }

  void _speak(SettingsController settings) {
    final l10n = AppLocalizations.of(context);
    context.read<AppState>().voice.speak(
      l10n.voiceTimeToTake(
        widget.entry.medicine.name,
        widget.entry.medicine.doseLabel,
      ),
      settings.settings.locale,
    );
  }

  String _elapsed(AppLocalizations l10n) {
    final diff = _now.difference(widget.entry.dose.scheduledAt);
    if (diff.isNegative) return '';
    if (diff.inMinutes == 0) return l10n.elapsedJustNow;
    if (diff.inMinutes < 60) return l10n.elapsedMinAgo(diff.inMinutes);
    return l10n.elapsedHourMinAgo(diff.inHours, diff.inMinutes % 60);
  }

  String _food(AppLocalizations l10n, FoodInstruction food) => switch (food) {
    FoodInstruction.none => '',
    FoodInstruction.before => l10n.foodBefore,
    FoodInstruction.after => l10n.foodAfter,
    FoodInstruction.withFood => l10n.foodWith,
  };

  String _frequency(AppLocalizations l10n, MedicineFrequency freq) =>
      switch (freq) {
        MedicineFrequency.daily => l10n.freqEveryDay,
        MedicineFrequency.specificDays => l10n.freqSpecificDays,
        MedicineFrequency.once => l10n.freqOnce,
        MedicineFrequency.multiple => l10n.freqMultiple,
      };

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final med = entry.medicine;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final appState = context.read<AppState>();
    final locale = settings.settings.locale;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: l10n.btnClose,
                icon: const Icon(Icons.close_rounded, size: AppSizes.iconXl),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                children: [
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) => Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.missedColor.withValues(
                              alpha: 0.35 + 0.45 * _pulse.value,
                            ),
                            width: 3,
                          ),
                        ),
                        child: child,
                      ),
                      child: Icon(
                        Icons.notifications_active_rounded,
                        size: 48,
                        color: theme.missedColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.alarmTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    med.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall,
                  ),
                  if (med.doseLabel.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      med.doseLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),

                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _AlarmRow(
                          icon: Icons.schedule_rounded,
                          label: AppDateUtils.timeLabel(
                            entry.dose.scheduledAt,
                            locale,
                          ),
                          trailing: _elapsed(l10n),
                        ),
                        if (_food(l10n, med.foodInstruction).isNotEmpty) ...[
                          const AppDivider(indent: 56),
                          _AlarmRow(
                            icon: Icons.restaurant_rounded,
                            label: _food(l10n, med.foodInstruction),
                          ),
                        ],
                        const AppDivider(indent: 56),
                        _AlarmRow(
                          icon: Icons.repeat_rounded,
                          label: _frequency(l10n, med.frequency),
                        ),
                        if (med.notes.trim().isNotEmpty) ...[
                          const AppDivider(indent: 56),
                          _AlarmRow(
                            icon: Icons.notes_rounded,
                            label: med.notes.trim(),
                          ),
                        ],
                        if (med.hasStockTracking && med.needsRefill) ...[
                          const AppDivider(indent: 56),
                          _AlarmRow(
                            icon: Icons.inventory_2_rounded,
                            label: l10n.medStockLeft(med.stockCount!),
                            highlight: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── The one action that matters ──────────────────────────
                  AppButton(
                    label: l10n.homeMarkAsTaken,
                    icon: Icons.check_rounded,
                    height: AppSizes.heroButton,
                    onPressed: () async {
                      await appState.markTaken(entry);
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton.secondary(
                    label: l10n.notifActionSnooze(settings.snoozeMinutes),
                    icon: Icons.snooze_rounded,
                    onPressed: () async {
                      await appState.markSnoozed(entry);
                      if (context.mounted) Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.quiet(
                          label: l10n.alarmLater,
                          icon: Icons.close_rounded,
                          onPressed: () async {
                            await appState.markSkipped(entry);
                            if (context.mounted) Navigator.of(context).maybePop();
                          },
                        ),
                      ),
                      AppIconButton(
                        icon: Icons.volume_up_rounded,
                        semanticLabel: l10n.speakReminder,
                        filled: false,
                        onPressed: () => _speak(settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.aboutBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlarmRow extends StatelessWidget {
  const _AlarmRow({
    required this.icon,
    required this.label,
    this.trailing,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = highlight
        ? theme.palette.warning
        : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppSizes.iconMd,
            color: highlight
                ? theme.palette.warning
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(color: color),
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty)
            Text(trailing!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
