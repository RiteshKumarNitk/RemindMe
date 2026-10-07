import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/auth_service.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_surfaces.dart';

/// Sign in with Google, or continue as a guest.
///
/// Shown on every launch until the user signs in with Google. Guests can look
/// around; adding medicines asks them to sign in (see `sign_in_gate.dart`).
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
    final scheme = theme.colorScheme;
    final auth = context.watch<AuthService>();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: CustomScrollView(
          slivers: [
            // ── Brand hero ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(
                  gradient: theme.brandGradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(36),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xl,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/dosewise_logo.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.medication_rounded,
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              l10n.obTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(
                          l10n.loginTitle,
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.splashTagline,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Benefits + actions ────────────────────────────────────────
            SliverFillRemaining(
              hasScrollBody: false,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Feature(
                        icon: Icons.notifications_active_rounded,
                        text: l10n.loginFeatureReminders,
                      ),
                      _Feature(
                        icon: Icons.family_restroom_rounded,
                        text: l10n.loginFeatureFamily,
                      ),
                      _Feature(
                        icon: Icons.insights_rounded,
                        text: l10n.loginFeatureHistory,
                      ),
                      const Spacer(),
                      const SizedBox(height: AppSpacing.xl),
                      if (auth.firebaseAvailable) ...[
                        AppButton(
                          label: l10n.loginWithGoogle,
                          icon: Icons.g_mobiledata_rounded,
                          busy: _busy,
                          onPressed: _busy ? null : _signInWithGoogle,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AppButton.secondary(
                        label: l10n.loginGuest,
                        icon: Icons.person_outline_rounded,
                        onPressed: _busy ? null : widget.onSkip,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.loginGuestNote,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(text, style: theme.textTheme.titleMedium)),
        ],
      ),
    );
  }
}
