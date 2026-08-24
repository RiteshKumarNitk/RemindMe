import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../widgets/big_button.dart';

/// First-run setup: welcome, optional name, then notification + exact-alarm
/// permission requests. Everything is skippable — banners in the app guide
/// the user later.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool askPermissions}) async {
    final settings = context.read<SettingsController>();
    final appState = context.read<AppState>();
    setState(() => _busy = true);

    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await settings.setUserName(name);
    }

    if (askPermissions) {
      await appState.requestAllPermissions();
      await appState.requestExactAlarms();
    }

    await settings.setOnboardingDone(true);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
          children: [
            Icon(
              Icons.medication_rounded,
              size: 88,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(l10n.obWelcome, style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              l10n.obTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.obBody, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 28),
            TextField(
              controller: _nameController,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                labelText: l10n.obName,
                hintText: l10n.obNameHint,
              ),
            ),
            const SizedBox(height: 32),
            BigButton(
              label: _busy ? '…' : l10n.obStart,
              icon: Icons.check_rounded,
              onPressed: _busy ? null : () => _finish(askPermissions: true),
            ),
            const SizedBox(height: 8),
            BigTextButton(
              label: l10n.obSkip,
              onPressed: _busy ? null : () => _finish(askPermissions: false),
            ),
          ],
        ),
      ),
    );
  }
}
