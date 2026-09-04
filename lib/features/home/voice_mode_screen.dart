import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';

/// Voice-first interface designed for visually impaired or low-vision users.
/// Shows large, high-contrast buttons with TTS for every action.
class VoiceModeScreen extends StatefulWidget {
  const VoiceModeScreen({super.key});

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Auto-announce the current status
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceStatus());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _speak(String text) {
    final appState = context.read<AppState>();
    final settings = context.read<SettingsController>();
    setState(() => _isSpeaking = true);
    appState.voice.speak(text, settings.settings.locale).then((_) {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  void _announceStatus() {
    final appState = context.read<AppState>();
    final settings = context.read<SettingsController>();
    final l10n = AppLocalizations.of(context);

    if (appState.loading) return;

    final next = appState.nextDose;

    if (next == null) {
      _speak(l10n.homeNoMoreToday);
    } else {
      final name = next.medicine.name;
      final dose = next.medicine.doseLabel;
      final time = AppDateUtils.timeLabel(
        next.dose.scheduledAt,
        settings.settings.locale,
      );
      _speak('${l10n.alarmTitle} $name, $dose, scheduled for $time');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    final settings = context.watch<SettingsController>();
    final locale = settings.settings.locale;

    final next = appState.nextDose;
    final stats = appState.todayStats;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Status indicator
            ScaleTransition(
              scale: CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isSpeaking
                      ? theme.colorScheme.primary.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isSpeaking
                        ? theme.colorScheme.primary
                        : Colors.white.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: Icon(
                  _isSpeaking ? Icons.volume_up_rounded : Icons.mic_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Current status text
            Text(
              _isSpeaking ? 'Speaking...' : 'Voice Mode',
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(flex: 1),

            // Next dose info card
            if (next != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      next.medicine.name,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      next.medicine.doseLabel,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppDateUtils.timeLabel(
                        next.dose.scheduledAt,
                        locale,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(flex: 2),

            // Big action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // TAKE button
                  if (next != null)
                    _VoiceButton(
                      label: l10n.homeMarkAsTaken,
                      icon: Icons.check_rounded,
                      color: theme.successColor,
                      onTap: () async {
                        _speak('Marking ${next.medicine.name} as taken');
                        await appState.markTaken(next);
                        if (mounted) {
                          await Future.delayed(const Duration(seconds: 1));
                          _announceStatus();
                        }
                      },
                    ),

                  const SizedBox(height: 16),

                  // SKIP button
                  if (next != null)
                    _VoiceButton(
                      label: l10n.alarmLater,
                      icon: Icons.skip_next_rounded,
                      color: theme.colorScheme.outline,
                      onTap: () async {
                        _speak('Skipping ${next.medicine.name}');
                        await appState.markSkipped(next);
                        if (mounted) {
                          await Future.delayed(const Duration(seconds: 1));
                          _announceStatus();
                        }
                      },
                    ),

                  const SizedBox(height: 16),

                  // REPEAT button
                  _VoiceButton(
                    label: l10n.speakReminder,
                    icon: Icons.replay_rounded,
                    color: theme.colorScheme.primary,
                    onTap: _announceStatus,
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // Today's progress
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ProgressStat(
                    value: '${stats.taken}',
                    label: l10n.homeTaken,
                    color: theme.successColor,
                  ),
                  _ProgressStat(
                    value: '${stats.pending}',
                    label: l10n.homeRemaining,
                    color: Colors.white,
                  ),
                  if (stats.missed > 0)
                    _ProgressStat(
                      value: '${stats.missed}',
                      label: l10n.homeMissed,
                      color: theme.missedColor,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      height: 80,
      child: Material(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 32, color: color),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
