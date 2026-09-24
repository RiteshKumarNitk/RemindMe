import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_surfaces.dart';

/// Voice-first screen for users who prefer to be told, not to read.
///
/// Everything announces itself out loud, the type is the largest in the app and
/// each action is a full-width 76pt target. It deliberately reuses the app's
/// own colours and spacing rather than inventing a separate dark theme — a
/// different-looking app is exactly what confuses the people this screen is
/// for.
class VoiceModeScreen extends StatefulWidget {
  const VoiceModeScreen({super.key});

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Auto-announce the current status.
    WidgetsBinding.instance.addPostFrameCallback((_) => _announceStatus());
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    final appState = context.read<AppState>();
    final settings = context.read<SettingsController>();
    setState(() => _isSpeaking = true);
    await appState.voice.speak(text, settings.settings.locale);
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _announceStatus() {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final settings = context.read<SettingsController>();
    final l10n = AppLocalizations.of(context);
    if (appState.loading) return;

    final next = appState.nextDose;
    if (next == null) {
      _speak(l10n.homeNoMoreToday);
      return;
    }
    final time = AppDateUtils.timeLabel(
      next.dose.scheduledAt,
      settings.settings.locale,
    );
    _speak('${l10n.alarmTitle} ${next.medicine.name}, '
        '${next.medicine.doseLabel}, $time');
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

    return AppPage(
      title: l10n.qaVoiceMode,
      subtitle: l10n.setVoiceOn,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _isSpeaking
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainer,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isSpeaking
                      ? theme.colorScheme.primary
                      : theme.cardBorder,
                  width: 3,
                ),
              ),
              child: child,
            ),
            child: Icon(
              _isSpeaking ? Icons.volume_up_rounded : Icons.mic_rounded,
              size: 44,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          _isSpeaking ? l10n.alarmTitle : l10n.qaVoiceMode,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (next != null)
          AppCard(
            child: Column(
              children: [
                Text(
                  next.medicine.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                if (next.medicine.doseLabel.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    next.medicine.doseLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppDateUtils.timeLabel(next.dose.scheduledAt, locale),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        if (next != null) ...[
          AppButton(
            label: l10n.homeMarkAsTaken,
            icon: Icons.check_rounded,
            height: 76,
            onPressed: () async {
              await _speak('${l10n.homeTaken} ${next.medicine.name}');
              await appState.markTaken(next);
              if (mounted) _announceStatus();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton.secondary(
            label: l10n.alarmLater,
            icon: Icons.skip_next_rounded,
            height: 76,
            onPressed: () async {
              await appState.markSkipped(next);
              if (mounted) _announceStatus();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton.secondary(
          label: l10n.speakReminder,
          icon: Icons.replay_rounded,
          height: 76,
          onPressed: _announceStatus,
        ),
        const SizedBox(height: AppSpacing.xl),
        AppCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ProgressStat(
                value: '${stats.taken}',
                label: l10n.homeTaken,
                color: theme.palette.success,
              ),
              _ProgressStat(
                value: '${stats.pending}',
                label: l10n.homeRemaining,
                color: theme.colorScheme.onSurface,
              ),
              if (stats.missed > 0)
                _ProgressStat(
                  value: '${stats.missed}',
                  label: l10n.homeMissed,
                  color: theme.colorScheme.error,
                ),
            ],
          ),
        ),
      ],
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
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
