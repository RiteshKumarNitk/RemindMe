import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/food_instruction.dart';
import '../../data/models/medicine_frequency.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';

/// Full-screen alarm overlay that appears when a dose is due right now.
///
/// Shows ALL medicine details the user entered during setup: name, dose,
/// food instruction, notes, frequency, and stock warnings.
/// Designed for elderly users: huge text, high-contrast colors, pulsing
/// animation, and oversized tap targets.
class DoseAlarmScreen extends StatefulWidget {
  const DoseAlarmScreen({super.key, required this.entry});

  final DoseEntry entry;

  @override
  State<DoseAlarmScreen> createState() => _DoseAlarmScreenState();
}

class _DoseAlarmScreenState extends State<DoseAlarmScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  DateTime _now = DateTime.now();
  Timer? _clockTimer;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..repeat(reverse: true);

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // Auto-dismiss after 60 seconds if not acted on
    _autoDismissTimer = Timer(const Duration(seconds: 60), () {
      if (mounted) Navigator.of(context).pop();
    });

    // Keep screen on while alarm is visible
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Auto-speak the reminder
    _autoSpeak();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _autoDismissTimer?.cancel();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _autoSpeak() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final settings = context.read<SettingsController>();
      if (settings.voiceEnabled) {
        final voice = context.read<AppState>().voice;
        final l10n = AppLocalizations.of(context);
        final text = l10n.voiceTimeToTake(
          widget.entry.medicine.name,
          widget.entry.medicine.doseLabel,
        );
        voice.speak(text, settings.settings.locale);
      }
    });
  }

  String _elapsed(AppLocalizations l10n) {
    final diff = _now.difference(widget.entry.dose.scheduledAt);
    if (diff.isNegative) return '';
    final mins = diff.inMinutes;
    if (mins == 0) return l10n.elapsedJustNow;
    if (mins < 60) return l10n.elapsedMinAgo(mins);
    final hrs = diff.inHours;
    final remMins = mins % 60;
    return l10n.elapsedHourMinAgo(hrs, remMins);
  }

  String _foodLabel(AppLocalizations l10n, FoodInstruction food) {
    return switch (food) {
      FoodInstruction.none => l10n.foodNone,
      FoodInstruction.before => l10n.foodBefore,
      FoodInstruction.after => l10n.foodAfter,
      FoodInstruction.withFood => l10n.foodWith,
    };
  }

  String _frequencyLabel(AppLocalizations l10n, MedicineFrequency freq) {
    return switch (freq) {
      MedicineFrequency.daily => l10n.freqEveryDay,
      MedicineFrequency.specificDays => l10n.freqSpecificDays,
      MedicineFrequency.once => l10n.freqOnce,
      MedicineFrequency.multiple => l10n.freqMultiple,
    };
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final med = entry.medicine;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final appState = context.read<AppState>();
    final locale = settings.settings.locale;

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.doseDueGradient[0],
                theme.doseDueGradient[0].withValues(alpha: 0.9),
                const Color(0xFF1A0505),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Close button at top
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, right: 8),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 32,
                      ),
                      tooltip: 'Dismiss',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Alarm icon with a pulsing glow ring (no zoom).
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final t = _pulseController.value;
                    return Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12 + 0.12 * t),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25 + 0.55 * t),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.28 * t),
                            blurRadius: 28 * t,
                            spreadRadius: 8 * t,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                // "Time to take your medicine!" title
                Text(
                  l10n.alarmTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 12),

                // Medicine name (big)
                Text(
                  med.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                // Dose label
                if (med.doseLabel.isNotEmpty)
                  Text(
                    med.doseLabel,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                const SizedBox(height: 12),

                // ── Detail chips ──────────────────────────────────────
                // Scheduled time + elapsed
                _AlarmChip(
                  icon: Icons.schedule_rounded,
                  label: AppDateUtils.timeLabel(entry.dose.scheduledAt, locale),
                  trailing: _elapsed(l10n).isNotEmpty ? _elapsed(l10n) : null,
                ),

                // Food instruction
                if (med.foodInstruction != FoodInstruction.none)
                  _AlarmChip(
                    icon: Icons.restaurant_rounded,
                    label: _foodLabel(l10n, med.foodInstruction),
                  ),

                // Frequency
                _AlarmChip(
                  icon: Icons.repeat_rounded,
                  label: _frequencyLabel(l10n, med.frequency),
                ),

                // Notes
                if (med.notes.isNotEmpty)
                  _AlarmChip(
                    icon: Icons.notes_rounded,
                    label: med.notes,
                    maxLines: 2,
                  ),

                // Stock warning
                if (med.hasStockTracking && med.needsRefill)
                  _AlarmChip(
                    icon: Icons.warning_amber_rounded,
                    label: l10n.medStockLeft(med.stockCount!),
                    highlight: true,
                  ),

                const Spacer(flex: 3),

                // Big "Take Now" button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: FilledButton(
                      onPressed: () async {
                        await appState.markTaken(entry);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.doseDueGradient[0],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 28),
                          const SizedBox(width: 12),
                          Text(l10n.homeMarkAsTaken),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Snooze button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        await appState.markSnoozed(entry);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.snooze_rounded),
                      label: Text(
                        l10n.notifActionSnooze(settings.snoozeMinutes),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () async {
                        await appState.markSkipped(entry);
                        if (context.mounted) Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l10n.alarmLater),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Voice repeat button
                TextButton.icon(
                  onPressed: () {
                    final voice = appState.voice;
                    final text = l10n.voiceTimeToTake(
                      med.name,
                      med.doseLabel,
                    );
                    voice.speak(text, settings.settings.locale);
                  },
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: Text(
                    l10n.speakReminder,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small info chip displayed on the alarm screen, with a glass-like style.
class _AlarmChip extends StatelessWidget {
  const _AlarmChip({
    required this.icon,
    required this.label,
    this.trailing,
    this.maxLines = 1,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String? trailing;
  final int maxLines;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFFC857).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: highlight
              ? Border.all(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.5),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: highlight
                  ? const Color(0xFFFFC857)
                  : Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
