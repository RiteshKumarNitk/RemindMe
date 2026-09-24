import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_surfaces.dart';

/// First-run setup in two short steps: welcome (and your name), then the two
/// permissions reminders actually need. Each step explains *why* in one plain
/// sentence, and every action stays at the bottom where a thumb can reach it.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.onComplete});

  /// Called when onboarding is complete (user taps Start or Skip).
  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  bool _busy = false;
  int _step = 0; // 0 = welcome, 1 = permissions

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = context.read<SettingsController>();
    final appState = context.read<AppState>();
    setState(() => _busy = true);

    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await settings.setUserName(name);
    }

    await appState.requestAllPermissions();
    await appState.requestExactAlarms();

    await settings.setOnboardingDone(true);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onComplete?.call();
  }

  Future<void> _skip() async {
    await context.read<SettingsController>().setOnboardingDone(true);
    if (!mounted) return;
    widget.onComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isLast = _step == 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepDots(step: _step, count: 2),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ListView(
                  children: _step == 0
                      ? _welcome(l10n, theme)
                      : _permissions(l10n, theme),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: isLast ? l10n.obStart : l10n.obStart,
                icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                busy: _busy,
                onPressed: _busy
                    ? null
                    : (isLast ? _finish : () => setState(() => _step = 1)),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppButton.quiet(
                label: l10n.obSkip,
                onPressed: _busy ? null : _skip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _welcome(AppLocalizations l10n, ThemeData theme) {
    return [
      Center(
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.medication_rounded,
            size: 52,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        l10n.obWelcome,
        style: theme.textTheme.displaySmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xxs),
      Text(
        l10n.obTitle,
        style: theme.textTheme.titleLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        l10n.obBody,
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xxl),
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        style: theme.textTheme.titleMedium,
        decoration: InputDecoration(
          labelText: l10n.obName,
          hintText: l10n.obNameHint,
          prefixIcon: const Icon(Icons.person_rounded),
        ),
      ),
    ];
  }

  List<Widget> _permissions(AppLocalizations l10n, ThemeData theme) {
    return [
      Center(
        child: Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.notifications_active_rounded,
            size: 52,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text(
        l10n.setPermissions,
        style: theme.textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xs),
      Text(
        l10n.setNotifDesc,
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            AppListRow(
              title: l10n.setNotifyPermission,
              subtitle: Text(l10n.setNotifDesc),
              leading: AppIconBubble(
                icon: Icons.notifications_active_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
            const AppDivider(indent: AppSpacing.md),
            AppListRow(
              title: l10n.setExactAlarm,
              subtitle: Text(l10n.setExactDesc),
              leading: AppIconBubble(
                icon: Icons.alarm_add_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      AppInfoNote(
        tone: AppNoteTone.info,
        message: l10n.permExactBody,
      ),
    ];
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: i == step ? 28 : 10,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: i <= step
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
              borderRadius: AppRadius.pillRadius,
            ),
          ),
      ],
    );
  }
}
