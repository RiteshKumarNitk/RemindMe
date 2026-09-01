import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/big_button.dart';

/// First-run two-step setup: welcome → permissions.
/// Each step has a clear explanation so elderly users understand WHY each
/// permission is needed.
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
  int _step = 0; // 0=welcome, 1=permissions

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

    // Grant permissions
    await appState.requestAllPermissions();
    await appState.requestExactAlarms();

    await settings.setOnboardingDone(true);
    if (mounted) setState(() => _busy = false);
    widget.onComplete?.call();
  }

  void _next() {
    if (_step < 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
          children: [
            // Step indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 2; i++)
                  Container(
                    width: i == _step ? 32 : 12,
                    height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i <= _step
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // Step content
            if (_step == 0) ..._buildWelcome(l10n, theme),
            if (_step == 1) ..._buildPermissions(l10n, theme),

            const SizedBox(height: 32),

            // Action buttons
            if (_step < 1)
              BigButton(
                label: _busy ? '…' : l10n.obStart,
                icon: Icons.arrow_forward_rounded,
                onPressed: _busy ? null : _next,
              ),
            if (_step == 1)
              BigButton(
                label: _busy ? '…' : l10n.obStart,
                icon: Icons.check_rounded,
                onPressed: _busy ? null : _finish,
              ),
            const SizedBox(height: 8),
            BigTextButton(
              label: l10n.obSkip,
              onPressed: _busy ? null : () async {
                final settings = context.read<SettingsController>();
                await settings.setOnboardingDone(true);
                widget.onComplete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWelcome(AppLocalizations l10n, ThemeData theme) {
    return [
      // Large decorative icon with background circle
      Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          child: Icon(
            Icons.medication_rounded,
            size: 72,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(height: 28),
      Text(
        l10n.obWelcome,
        style: theme.textTheme.displaySmall,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        l10n.obTitle,
        style: theme.textTheme.headlineMedium?.copyWith(
          color: theme.colorScheme.primary,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      Text(
        l10n.obBody,
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 32),
      TextField(
        controller: _nameController,
        style: theme.textTheme.titleMedium,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: l10n.obName,
          hintText: l10n.obNameHint,
          prefixIcon: const Icon(Icons.person_rounded),
        ),
      ),
    ];
  }

  List<Widget> _buildPermissions(AppLocalizations l10n, ThemeData theme) {
    return [
      Icon(
        Icons.notifications_active_rounded,
        size: 64,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 20),
      Text(
        l10n.setPermissions,
        style: theme.textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        l10n.setNotifDesc,
        style: theme.textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      _PermissionCard(
        icon: Icons.notifications_active_rounded,
        title: l10n.setNotifyPermission,
        subtitle: l10n.setNotifDesc,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 12),
      _PermissionCard(
        icon: Icons.alarm_add_rounded,
        title: l10n.setExactAlarm,
        subtitle: l10n.setExactDesc,
        color: theme.colorScheme.secondary,
      ),
    ];
  }


}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
