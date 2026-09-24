import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart' show RootScreen;
import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/account_deletion_service.dart';
import '../../services/auth_service.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../settings/settings_screen.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_status.dart';
import '../widgets/app_surfaces.dart';

/// Who you are and what happens to your account.
///
/// One screen, four blocks: identity, personal details, sign-in state, and the
/// destructive zone — which stays last, in red, behind a confirmation.
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

    return AppPage(
      title: l10n.profileTitle,
      children: [
        _Identity(
          auth: auth,
          settings: settings,
          l10n: l10n,
        ),

        const SizedBox(height: AppSpacing.xl),
        AppSectionHeader(title: l10n.profilePersonalInfo),
        const SizedBox(height: AppSpacing.sm),

        if (_editing)
          AppCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: l10n.obName,
                    hintText: l10n.obNameHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.profileAge,
                    hintText: l10n.profileAgeHint,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: AppButton.secondary(
                        label: l10n.btnCancel,
                        height: 52,
                        onPressed: () => setState(() {
                          _editing = false;
                          _nameController.text = settings.userName;
                          _ageController.text =
                              settings.settings.userAge?.toString() ?? '';
                        }),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AppButton(
                        label: l10n.btnSave,
                        height: 52,
                        busy: _saving,
                        onPressed: _saving ? null : _saveProfile,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else ...[
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_details(auth, settings, l10n).isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      children: [
                        Text(
                          l10n.profileNoInfoYet,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton.secondary(
                          label: l10n.profileEditInfo,
                          icon: Icons.edit_rounded,
                          height: 52,
                          onPressed: () => setState(() => _editing = true),
                        ),
                      ],
                    ),
                  )
                else ...[
                  for (final row in _details(auth, settings, l10n)) ...[
                    AppListRow(
                      title: row.label,
                      subtitle: Text(row.value),
                      leading: AppIconBubble(
                        icon: row.icon,
                        color: theme.colorScheme.primary,
                      ),
                      dense: true,
                    ),
                    const AppDivider(indent: AppSpacing.md),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: AppButton.secondary(
                      label: l10n.profileEditInfo,
                      icon: Icons.edit_rounded,
                      height: 52,
                      onPressed: () => setState(() => _editing = true),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        AppSectionHeader(title: l10n.profileAccount),
        const SizedBox(height: AppSpacing.sm),

        if (auth.isSignedIn)
          AppCard(
            padding: EdgeInsets.zero,
            child: AppListRow(
              title: l10n.profileSignOut,
              titleColor: theme.colorScheme.error,
              subtitle: Text(l10n.profileSignOutDesc),
              leading: AppIconBubble(
                icon: Icons.logout_rounded,
                color: theme.colorScheme.error,
                background: theme.colorScheme.errorContainer,
              ),
              onTap: () => _confirmSignOut(context, auth, l10n),
            ),
          )
        else
          AppCard(
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: 40,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.profileSignInPrompt,
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (auth.firebaseAvailable) ...[
                  const SizedBox(height: AppSpacing.md),
                  AppButton.secondary(
                    label: l10n.syncGoogleSignIn,
                    icon: Icons.g_mobiledata_rounded,
                    height: 52,
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final user = await auth.signInWithGoogle();
                      if (user != null && mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text(l10n.profileWelcomeBack)),
                        );
                      }
                    },
                  ),
                ],
              ],
            ),
          ),

        if (kDebugMode && !auth.isSignedIn) ...[
          const SizedBox(height: AppSpacing.md),
          _DiagnosticCard(auth: auth),
        ],

        const SizedBox(height: AppSpacing.xl),
        AppSectionHeader(title: l10n.setTitle),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: AppListRow(
            title: l10n.setTitle,
            subtitle: Text(l10n.setGroupReminders),
            leading: AppIconBubble(
              icon: Icons.settings_rounded,
              color: theme.colorScheme.primary,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),
        AppSectionHeader(title: l10n.setAbout),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.appTitle} · 1.0.1',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(l10n.aboutBody, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xxl),
        AppSectionHeader(title: l10n.profileDangerZone),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: l10n.profileDeleteAccount,
          icon: Icons.delete_forever_rounded,
          tone: AppButtonTone.danger,
          onPressed: () => _confirmDeleteAccount(context, auth, l10n),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.profileDeleteAccountDesc,
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  List<({IconData icon, String label, String value})> _details(
    AuthService auth,
    SettingsController settings,
    AppLocalizations l10n,
  ) {
    final rows = <({IconData icon, String label, String value})>[];
    final name = settings.userName.isNotEmpty
        ? settings.userName
        : auth.displayName;
    if (name.trim().isNotEmpty) {
      rows.add((icon: Icons.person_rounded, label: l10n.obName, value: name));
    }
    final age = settings.settings.userAge;
    if (age != null) {
      rows.add((
        icon: Icons.cake_rounded,
        label: l10n.profileAge,
        value: '$age',
      ));
    }
    if (auth.isSignedIn && auth.email.isNotEmpty) {
      rows.add((
        icon: Icons.email_rounded,
        label: l10n.profileEmail,
        value: auth.email,
      ));
    }
    return rows;
  }

  Future<void> _saveProfile() async {
    final settings = context.read<SettingsController>();
    final auth = context.read<AuthService>();
    setState(() => _saving = true);

    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      await settings.setUserName(name);
      if (auth.isSignedIn) {
        await auth.updateDisplayName(name);
      }
    }
    await settings.setUserAge(int.tryParse(_ageController.text.trim()));

    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).profileSaved)),
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthService auth,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.profileSignOut,
      message: l10n.profileSignOutConfirm,
      confirmLabel: l10n.profileSignOut,
      cancelLabel: l10n.btnCancel,
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !context.mounted) return;
    await auth.signOut();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.profileSignedOut)));
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AuthService auth,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.profileDeleteAccountConfirmTitle,
      message: auth.isSignedIn
          ? '${l10n.profileDeleteAccountConfirmBody}\n\n${l10n.profileDeleteAccountConfirmBodySignedIn}'
          : l10n.profileDeleteAccountConfirmBody,
      confirmLabel: l10n.profileDeleteAccountButton,
      cancelLabel: l10n.btnCancel,
      icon: Icons.delete_forever_rounded,
    );
    if (!confirmed || !context.mounted) return;
    await _runDeletion(context, l10n);
  }

  Future<void> _runDeletion(BuildContext context, AppLocalizations l10n) async {
    final deletion = context.read<AccountDeletionService>();
    final auth = context.read<AuthService>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final result = await deletion.deleteEverything();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close the spinner

    if (result.requiresRecentLogin) {
      final retry = await showAppConfirmDialog(
        context,
        title: l10n.profileDeleteAccountReauthTitle,
        message: l10n.profileDeleteAccountReauthBody,
        confirmLabel: l10n.profileDeleteAccountReauthButton,
        cancelLabel: l10n.btnCancel,
        destructive: false,
        icon: Icons.lock_reset_rounded,
      );
      if (retry && context.mounted) {
        final user = await auth.signInWithGoogle();
        if (user != null && context.mounted) {
          await _runDeletion(context, l10n);
        }
      }
      // Local data was NOT wiped on a requires-recent-login outcome (the
      // cloud steps ran first and this path returns before a local wipe would
      // make sense) — nothing further to do if the user declines.
      return;
    }

    if (!context.mounted) return;

    final messages = <String>[
      result.fullyCleaned
          ? l10n.profileDeleteAccountDone
          : l10n.profileDeleteAccountPartial,
      if (!result.householdPresenceRemoved) l10n.profileDeleteAccountOwnerNote,
    ];

    await showAppInfoDialog(
      context,
      title: l10n.profileDeleteAccountConfirmTitle,
      content: Text(messages.join('\n\n')),
      closeLabel: l10n.btnClose,
      icon: Icons.check_circle_rounded,
    );

    if (!context.mounted) return;

    // Local settings/DB are now empty on disk — reload the in-memory
    // controllers to match, then rebuild the whole app from a fresh
    // RootScreen so it re-evaluates signed-in/onboarding state (both now
    // false) and lands back on Login, not a stale Home screen.
    final settingsCtrl = context.read<SettingsController>();
    final appStateCtrl = context.read<AppState>();
    await settingsCtrl.load();
    await appStateCtrl.refresh();
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RootScreen()),
      (route) => false,
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({
    required this.auth,
    required this.settings,
    required this.l10n,
  });

  final AuthService auth;
  final SettingsController settings;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = settings.userName.isNotEmpty
        ? settings.userName
        : (auth.displayName.isNotEmpty
              ? auth.displayName
              : (auth.isSignedIn ? l10n.profileNoName : l10n.profileGuestUser));

    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: theme.colorScheme.surfaceContainer,
          backgroundImage: auth.photoUrl.isNotEmpty
              ? NetworkImage(auth.photoUrl)
              : null,
          child: auth.photoUrl.isEmpty
              ? Icon(
                  Icons.person_rounded,
                  size: 44,
                  color: theme.colorScheme.primary,
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(name, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
        if (auth.isSignedIn && auth.email.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            auth.email,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        AppPill(
          label: auth.isSignedIn ? l10n.profileSignedIn : l10n.profileOfflineMode,
          icon: auth.isSignedIn
              ? Icons.cloud_done_rounded
              : Icons.cloud_off_rounded,
          color: auth.isSignedIn
              ? theme.palette.success
              : theme.colorScheme.onSurfaceVariant,
          background: auth.isSignedIn
              ? theme.palette.successContainer
              : theme.palette.neutralContainer,
        ),
      ],
    );
  }
}

/// Debug-only Firebase diagnostics. Never shown in release builds.
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
    return AppCard(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.build_circle_rounded,
                size: AppSizes.iconLg,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Firebase diagnostics',
                  style: theme.textTheme.titleMedium,
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
          const SizedBox(height: AppSpacing.sm),
          for (final entry in _results.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.key, style: theme.textTheme.labelLarge),
                  Text(
                    entry.value,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: entry.value.startsWith('✅')
                          ? theme.palette.success
                          : entry.value.startsWith('❌')
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          AppButton.secondary(
            label: 'Re-run diagnostics',
            icon: Icons.refresh_rounded,
            height: 52,
            onPressed: _running ? null : _runDiagnostics,
          ),
        ],
      ),
    );
  }
}
