import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../services/auth_service.dart';
import '../../services/settings_controller.dart';
import '../../services/sync/sync_service.dart';
import '../caregiver/caregiver_dashboard_screen.dart';
import '../widgets/big_button.dart';

/// Phase 2: family sync setup. Create a family (primary) or join one with a
/// 6-letter code (watcher). Degrades gracefully when Firebase isn't
/// configured — the app keeps working fully offline.
class FamilySyncScreen extends StatefulWidget {
  const FamilySyncScreen({super.key});

  @override
  State<FamilySyncScreen> createState() => _FamilySyncScreenState();
}

class _FamilySyncScreenState extends State<FamilySyncScreen> {
  bool _busy = false;
  String? _authError;

  Future<void> _enable(String role, {String? code}) async {
    final sync = context.read<SyncService>();
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await sync.enableSync(role: role, joinCode: code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(role == 'watcher' ? l10n.syncJoin : l10n.syncCreate),
          ),
        );
      }
    } catch (_) {
      // error surfaced below via sync.lastError
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askCode() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.syncCodeLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.syncPrimaryHint,
              style: Theme.of(dialogContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
                letterSpacing: 4,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(hintText: l10n.syncCodeHint),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: Text(l10n.syncJoin),
          ),
        ],
      ),
    );
    if (code != null && code.isNotEmpty) {
      await _enable('watcher', code: code);
    }
  }

  Future<void> _confirmDisable() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.syncDisable),
        content: Text(l10n.syncDisableConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).missedColor,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.syncDisable),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SyncService>().disableSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familySync)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Firebase not configured warning
          if (!auth.firebaseAvailable) ...[
            Card(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      color: theme.colorScheme.onErrorContainer,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l10n.familySyncNotConfigured,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Google Sign-In card
          if (!auth.isSignedIn && auth.firebaseAvailable) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_circle_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.familySyncIntro,
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () async {
                          setState(() {
                            _busy = true;
                            _authError = null;
                          });
                          final user = await auth.signInWithGoogle();
                          if (mounted) {
                            setState(() {
                              _busy = false;
                              if (user == null) {
                                _authError = l10n.syncSignInFailed;
                              }
                            });
                          }
                        },
                        icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
                        label: Text(l10n.syncGoogleSignIn),
                      ),
                    ),
                    if (_authError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              color: theme.colorScheme.onErrorContainer,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _authError!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Signed-in user card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text(
                        auth.displayName.isNotEmpty
                            ? auth.displayName[0].toUpperCase()
                            : '?',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.displayName.isNotEmpty
                                ? auth.displayName
                                : auth.email,
                            style: theme.textTheme.titleMedium,
                          ),
                          if (auth.email.isNotEmpty && auth.displayName.isNotEmpty)
                            Text(
                              auth.email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.syncSignOut,
                      icon: const Icon(Icons.logout_rounded),
                      onPressed: () => auth.signOut(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (sync.enabled) ...[
            _StatusCard(sync: sync, l10n: l10n),
            const SizedBox(height: 20),
            // The shareable code — anyone can hand this to family.
            _CodeCard(sync: sync, l10n: l10n),
            const SizedBox(height: 16),
            // Everyone can also help watch a family member: alerts + dashboard.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.missedAlerts),
              subtitle: Text(l10n.missedAlertsDesc),
              value: context.read<SettingsController>().missedAlertsEnabled,
              onChanged: (v) => context
                  .read<SettingsController>()
                  .setMissedAlertsEnabled(v),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.insights_rounded,
              title: l10n.caregiverTitle,
              subtitle: l10n.caregiverDesc,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CaregiverDashboardScreen(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            BigButton(
              label: l10n.syncJoinAnother,
              icon: Icons.group_add_rounded,
              outlined: true,
              height: 56,
              onPressed: _busy ? null : _askCode,
            ),
            const SizedBox(height: 8),
            BigButton(
              label: sync.syncing ? l10n.syncStatusSyncing : l10n.syncNow,
              icon: Icons.sync_rounded,
              outlined: true,
              height: 56,
              onPressed: sync.syncing ? null : () => sync.syncNow(),
            ),
            const SizedBox(height: 12),
            BigButton(
              label: l10n.syncDisable,
              icon: Icons.link_off_rounded,
              height: 56,
              onPressed: _confirmDisable,
            ),
          ] else ...[
            Text(l10n.syncSetupHint, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 18),
            BigButton(
              label: l10n.syncCreateCode,
              icon: Icons.qr_code_2_rounded,
              height: 60,
              onPressed: _busy ? null : () => _enable('primary'),
            ),
            const SizedBox(height: 12),
            BigButton(
              label: l10n.syncHaveCode,
              icon: Icons.login_rounded,
              outlined: true,
              height: 56,
              onPressed: _busy ? null : _askCode,
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (sync.lastError != null) ...[
            const SizedBox(height: 20),
            _SyncErrorCard(raw: sync.lastError!, l10n: l10n),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.sync, required this.l10n});

  final SyncService sync;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastSync = sync.lastSyncAt;
    final color = sync.lastError != null
        ? theme.missedColor
        : theme.successColor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              sync.syncing
                  ? Icons.sync_rounded
                  : sync.lastError != null
                  ? Icons.error_outline_rounded
                  : Icons.cloud_done_rounded,
              size: 34,
              color: color,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sync.syncing
                        ? l10n.syncStatusSyncing
                        : sync.lastError != null
                        ? l10n.syncFailed
                        : l10n.syncStatusSynced,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    lastSync == null
                        ? l10n.syncNever
                        : l10n.syncLastSync(
                            AppDateUtils.timeLabel(lastSync, Localizations.localeOf(context).languageCode),
                          ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (sync.pendingCount > 0)
                    Text(
                      l10n.syncPendingCount(sync.pendingCount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.missedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (sync.nextRetryAt != null)
                    Text(
                      l10n.syncRetrying,
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

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.sync, required this.l10n});

  final SyncService sync;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              l10n.syncCodeShare,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              sync.householdCode,
              style: theme.textTheme.displaySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                letterSpacing: 8,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: sync.householdCode),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(l10n.syncCopied)));
                }
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(l10n.syncCodeLabel),
            ),
          ],
        ),
      ),
    );
  }
}

/// Turns a raw backend exception string into an actionable message, with the
/// original text tucked behind an expandable "Details".
class _SyncErrorCard extends StatelessWidget {
  const _SyncErrorCard({required this.raw, required this.l10n});

  final String raw;
  final AppLocalizations l10n;

  String get _friendly {
    final e = raw.toLowerCase();
    if (e.contains('not configured')) return l10n.syncNotConfigured;
    if (e.contains('permission-denied') ||
        e.contains('permission_denied') ||
        e.contains('insufficient permissions')) {
      return l10n.syncErrorPermission;
    }
    if (e.contains('unavailable') ||
        e.contains('network') ||
        e.contains('timeout') ||
        e.contains('could not reach') ||
        e.contains('deadline')) {
      return l10n.syncErrorNetwork;
    }
    if (e.contains('operation-not-allowed') ||
        e.contains('admin-restricted-operation') ||
        e.contains('sign_in') ||
        e.contains('sign-in') ||
        e.contains('api-key-not-valid') ||
        e.contains('auth')) {
      return l10n.syncErrorAuth;
    }
    return l10n.syncFailed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onErr = theme.colorScheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: onErr, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _friendly,
                  style: theme.textTheme.bodyMedium?.copyWith(color: onErr),
                ),
              ),
            ],
          ),
          Theme(
            data: theme.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(
                l10n.syncErrorDetail,
                style: theme.textTheme.labelLarge?.copyWith(color: onErr),
              ),
              iconColor: onErr,
              collapsedIconColor: onErr,
              children: [
                SelectableText(
                  raw,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: onErr,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 40, color: theme.colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
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
              Icon(
                Icons.chevron_right_rounded,
                size: 32,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
