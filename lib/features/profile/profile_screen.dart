import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/settings_controller.dart';
import '../settings/settings_screen.dart';

/// Profile screen: shows user info, allows editing name/age, and logout.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsController>();
    _nameController = TextEditingController(text: settings.userName);
    _ageController = TextEditingController(
      text: settings.settings.userAge?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final settings = context.watch<SettingsController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(l10n.profileTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 24),

            // Profile header with photo/avatar
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 52,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    backgroundImage: auth.photoUrl.isNotEmpty
                        ? NetworkImage(auth.photoUrl)
                        : null,
                    child: auth.photoUrl.isEmpty
                        ? Icon(
                            Icons.person_rounded,
                            size: 52,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (auth.isSignedIn) ...[
                    Text(
                      auth.displayName.isNotEmpty ? auth.displayName : l10n.profileNoName,
                      style: theme.textTheme.headlineSmall,
                    ),
                    if (auth.email.isNotEmpty)
                      Text(
                        auth.email,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.profileSignedIn,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ] else ...[
                    Text(
                      settings.userName.isNotEmpty
                          ? settings.userName
                          : l10n.profileGuestUser,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        l10n.profileOfflineMode,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Personal info section
            _SectionHeader(l10n.profilePersonalInfo),
            const SizedBox(height: 8),

            // Name field
            if (_editing) ...[
              TextField(
                controller: _nameController,
                style: theme.textTheme.titleMedium,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.obName,
                  hintText: l10n.obNameHint,
                  prefixIcon: const Icon(Icons.person_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),

              // Age field
              TextField(
                controller: _ageController,
                style: theme.textTheme.titleMedium,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.profileAge,
                  hintText: l10n.profileAgeHint,
                  prefixIcon: const Icon(Icons.cake_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Save / Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _editing = false;
                          _nameController.text = settings.userName;
                          _ageController.text =
                              settings.settings.userAge?.toString() ?? '';
                        });
                      },
                      child: Text(l10n.btnCancel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _saveProfile,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.btnSave),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Display mode — only render fields we actually have.
              Builder(
                builder: (context) {
                  final rows = <Widget>[];
                  void add(IconData icon, String label, String? value) {
                    if (value == null || value.trim().isEmpty) return;
                    if (rows.isNotEmpty) rows.add(const Divider());
                    rows.add(_InfoRow(icon: icon, label: label, value: value));
                  }

                  final name = settings.userName.isNotEmpty
                      ? settings.userName
                      : (auth.displayName.isNotEmpty ? auth.displayName : null);
                  add(Icons.person_rounded, l10n.obName, name);
                  add(
                    Icons.cake_rounded,
                    l10n.profileAge,
                    settings.settings.userAge?.toString(),
                  );
                  if (auth.isSignedIn) {
                    add(Icons.email_rounded, l10n.profileEmail, auth.email);
                  }

                  if (rows.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Text(
                        l10n.profileNoInfoYet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: rows),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_rounded),
                  label: Text(l10n.profileEditInfo),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Account section
            _SectionHeader(l10n.profileAccount),
            const SizedBox(height: 8),

            if (auth.isSignedIn) ...[
              // Sign out button
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  minTileHeight: 60,
                  leading: Icon(
                    Icons.logout_rounded,
                    size: 28,
                    color: theme.colorScheme.error,
                  ),
                  title: Text(
                    l10n.profileSignOut,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                  subtitle: Text(l10n.profileSignOutDesc),
                  onTap: () => _confirmSignOut(context, auth, l10n),
                ),
              ),
            ] else ...[
              // Sign in prompt
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.profileSignInPrompt,
                        style: theme.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (auth.firebaseAvailable)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final user = await auth.signInWithGoogle();
                              if (user != null && mounted) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text(l10n.profileWelcomeBack)),
                                );
                              }
                            },
                            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                            label: Text(l10n.syncGoogleSignIn),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // Firebase diagnostics — debug builds only, never in production.
            if (kDebugMode && !auth.isSignedIn) ...[
              const SizedBox(height: 16),
              _DiagnosticCard(auth: auth),
            ],
            const SizedBox(height: 24),

            // Settings link
            _SectionHeader(l10n.setTitle),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                minTileHeight: 60,
                leading: Icon(
                  Icons.settings_rounded,
                  size: 28,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.setTitle, style: theme.textTheme.titleMedium),
                subtitle: Text(
                  l10n.familySyncDesc,
                  style: theme.textTheme.bodyMedium,
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  size: 30,
                  color: theme.colorScheme.outline,
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App info
            _SectionHeader(l10n.setAbout),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.appTitle} · v1.0.0',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.aboutBody, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    final settings = context.read<SettingsController>();
    final auth = context.read<AuthService>();
    setState(() => _saving = true);

    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await settings.setUserName(name);
      // Also update Firebase display name if signed in
      if (auth.isSignedIn) {
        await auth.updateDisplayName(name);
      }
    }

    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);
    await settings.setUserAge(age);

    if (mounted) {
      setState(() {
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
      );
    }
  }

  void _confirmSignOut(
    BuildContext context,
    AuthService auth,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileSignOut),
        content: Text(l10n.profileSignOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileSignOut),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await auth.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileSignedOut)),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 24, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.titleMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiagnosticCard extends StatefulWidget {
  const _DiagnosticCard({required this.auth});

  final AuthService auth;

  @override
  State<_DiagnosticCard> createState() => _DiagnosticCardState();
}

class _DiagnosticCardState extends State<_DiagnosticCard> {
  Map<String, String> _results = {};
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostics();
  }

  Future<void> _runDiagnostics() async {
    setState(() => _running = true);
    final results = await widget.auth.runDiagnostics();
    if (mounted) {
      setState(() {
        _results = results;
        _running = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.build_circle_rounded,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Firebase Diagnostics',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_running)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_results.isEmpty && !_running)
              Text(
                'Tap to check Firebase configuration',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final entry in _results.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        entry.value,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: entry.value.startsWith('✅')
                              ? theme.colorScheme.primary
                              : entry.value.startsWith('❌')
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _running ? null : _runDiagnostics,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Re-run Diagnostics'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
