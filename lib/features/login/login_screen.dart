import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/auth_service.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_surfaces.dart';

/// Sign in with Google, or use the app entirely offline.
///
/// Offline is a first-class choice here, not a hidden escape hatch: this app
/// reminds you about medicine without any account at all.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onSkip, this.onSignedIn});

  final VoidCallback onSkip;
  final VoidCallback? onSignedIn;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _signInWithGoogle() async {
    final auth = context.read<AuthService>();
    setState(() => _busy = true);

    final user = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (user != null) widget.onSignedIn?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xxl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Center(
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.medication_rounded,
                  size: 60,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              l10n.obTitle,
              style: theme.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.loginSubtitle,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxl),

            if (auth.firebaseAvailable) ...[
              AppButton(
                label: l10n.loginWithGoogle,
                icon: Icons.g_mobiledata_rounded,
                busy: _busy,
                onPressed: _busy ? null : _signInWithGoogle,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(l10n.loginOr, style: theme.textTheme.bodyMedium),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            AppButton.secondary(
              label: l10n.loginSkip,
              icon: Icons.arrow_forward_rounded,
              onPressed: _busy ? null : widget.onSkip,
            ),

            if (auth.hasError) ...[
              const SizedBox(height: AppSpacing.lg),
              AppInfoNote(
                tone: AppNoteTone.danger,
                title: l10n.loginWithGoogle,
                message: auth.error!,
                actionLabel: l10n.errorRetry,
                actionIcon: Icons.refresh_rounded,
                onAction: () {
                  auth.clearError();
                  _signInWithGoogle();
                },
              ),
              if (kDebugMode && auth.debugInfo != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  auth.debugInfo!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ],
            ],

            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.loginOfflineNote,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
