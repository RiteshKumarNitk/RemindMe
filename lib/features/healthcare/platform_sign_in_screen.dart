import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../services/platform_auth_service.dart';

/// Sign in to the clinic platform.
///
/// This is the account that owns appointments — the same email and password
/// a patient would use on the clinic's website. The medicine-reminder side of
/// DoseWise keeps working with or without it.
class PlatformSignInScreen extends StatefulWidget {
  const PlatformSignInScreen({super.key});

  @override
  State<PlatformSignInScreen> createState() => _PlatformSignInScreenState();
}

class _PlatformSignInScreenState extends State<PlatformSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _registering = false;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final account = context.read<PlatformAuthService>();

    setState(() => _busy = true);
    final ok = _registering
        ? await account.register(
            fullName: _name.text,
            email: _email.text,
            password: _password.text,
          )
        : await account.signIn(
            email: _email.text,
            password: _password.text,
          );

    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      navigator.pop(true);
      return;
    }

    final error = account.lastError;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error != null && !error.isNetworkIssue
              ? error.message
              : l10n.hcSignInFailed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hcSignIn)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            l10n.hcSignInTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.hcSignInBody,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                if (_registering) ...[
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.hcFullNameLabel,
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.hcFieldRequired
                        : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l10n.hcEmailLabel,
                    prefixIcon: const Icon(Icons.mail_rounded),
                  ),
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return l10n.hcFieldRequired;
                    if (!text.contains('@') || !text.contains('.')) {
                      return l10n.hcEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.hcPasswordLabel,
                    prefixIcon: const Icon(Icons.lock_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.isEmpty) return l10n.hcFieldRequired;
                    // The platform requires at least 10 characters.
                    if (text.length < 10) return l10n.hcPasswordTooShort;
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _registering ? l10n.hcCreateAccount : l10n.hcSignIn,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _registering = !_registering),
              child: Text(
                _registering ? l10n.hcHaveAccount : l10n.hcNoAccount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
