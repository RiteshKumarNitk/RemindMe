import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/auth_service.dart';
import '../widgets/app_buttons.dart';

/// Guests can look around, but adding a medicine needs a Google account.
///
/// Returns true when the user is (or has just become) signed in with Google.
/// Shows a sign-in sheet otherwise; "Not now" returns false.
Future<bool> ensureGoogleSignIn(BuildContext context) async {
  if (context.read<AuthService>().isGoogleSignedIn) return true;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.lg + 4),
      ),
    ),
    builder: (_) => const _SignInSheet(),
  );
  return ok ?? false;
}

class _SignInSheet extends StatefulWidget {
  const _SignInSheet();

  @override
  State<_SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<_SignInSheet> {
  bool _busy = false;

  Future<void> _signIn() async {
    final auth = context.read<AuthService>();
    setState(() => _busy = true);
    final user = await auth.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (user != null && auth.isGoogleSignedIn) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final scheme = theme.colorScheme;

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: theme.brandGradient,
                  borderRadius: BorderRadius.circular(AppRadius.md + 4),
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.signInRequiredTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.signInRequiredBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (auth.hasError) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                auth.error!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.loginWithGoogle,
              icon: Icons.g_mobiledata_rounded,
              busy: _busy,
              onPressed: _busy || !auth.firebaseAvailable ? null : _signIn,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: Text(l10n.signInNotNow),
            ),
          ],
        ),
      ),
    );
  }
}
