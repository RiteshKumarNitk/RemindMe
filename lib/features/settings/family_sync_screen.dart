import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../services/auth_service.dart';
import '../../services/settings_controller.dart';
import '../../services/sync/invitation_service.dart';
import '../../services/sync/sync_service.dart';
import '../caregiver/caregiver_dashboard_screen.dart';
import '../widgets/big_button.dart';
import 'family_qr_scan_screen.dart';
import 'family_qr_show_screen.dart';

/// Family sync screen with QR-code based family connection flow.
///
/// When sync is NOT enabled:
///   - Create Family / Join Family options
///
/// When sync IS enabled:
///   - Family members list
///   - Add Family Member (QR scan / QR show)
///   - Caregiver dashboard
///   - Sync controls
class FamilySyncScreen extends StatefulWidget {
  const FamilySyncScreen({super.key});

  @override
  State<FamilySyncScreen> createState() => _FamilySyncScreenState();
}

class _FamilySyncScreenState extends State<FamilySyncScreen> {
  bool _busy = false;
  String? _authError;
  List<FamilyMember> _members = [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<SyncService>().enabled) {
        _loadMembers();
      }
    });
  }

  Future<void> _loadMembers() async {
    final sync = context.read<SyncService>();
    if (!sync.enabled) return;

    setState(() => _loadingMembers = true);
    try {
      final service = InvitationService();
      final members = await service.getFamilyMembers(sync.householdCode);
      if (mounted) {
        setState(() {
          _members = members;
          _loadingMembers = false;
        });
      }
    } catch (e) {
      developer.log('Failed to load members: $e', name: 'FamilySync');
      if (mounted) setState(() => _loadingMembers = false);
    }
  }

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
        _loadMembers();
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
    controller.dispose();
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
      setState(() => _members = []);
    }
  }

  void _showAddMemberOptions() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Add Family Member',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how to connect a family member',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            // Scan QR Code option
            _AddMemberOption(
              icon: Icons.qr_code_scanner_rounded,
              title: 'Scan QR Code',
              subtitle: 'Scan another family member\'s QR code',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const FamilyQrScanScreen(),
                  ),
                ).then((result) {
                  if (result == true) _loadMembers();
                });
              },
            ),
            const SizedBox(height: 12),

            // Show My QR Code option
            _AddMemberOption(
              icon: Icons.qr_code_2_rounded,
              title: 'Show My QR Code',
              subtitle: 'Let a family member scan your QR code',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FamilyQrShowScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Legacy code option
            _AddMemberOption(
              icon: Icons.keyboard_rounded,
              title: 'Enter Code Manually',
              subtitle: 'Type a 6-letter family code',
              onTap: () {
                Navigator.of(ctx).pop();
                _askCode();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncService>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.familySync),
      ),
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
                        onPressed: _busy
                            ? null
                            : () async {
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
                          if (auth.email.isNotEmpty &&
                              auth.displayName.isNotEmpty)
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

            // My Family section
            _SectionHeader('My Family'),
            const SizedBox(height: 8),

            // Family members list
            if (_loadingMembers)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_members.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No family members yet. Add someone to get started!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
            else
              for (final member in _members)
                _MemberTile(
                  member: member,
                  isCurrentUser: member.uid == auth.uid,
                  isAdmin: sync.role == 'primary' || sync.role == 'admin',
                  onRemove: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Remove Member'),
                        content: Text(
                          'Remove ${member.name} from the family?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: Text(l10n.btnCancel),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.missedColor,
                            ),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      try {
                        final service = InvitationService();
                        await service.removeMember(
                          householdCode: sync.householdCode,
                          adminUid: auth.uid,
                          memberUid: member.uid,
                        );
                        _loadMembers();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to remove: $e')),
                          );
                        }
                      }
                    }
                  },
                ),

            const SizedBox(height: 16),

            // Add Family Member button
            BigButton(
              label: 'Add Family Member',
              icon: Icons.group_add_rounded,
              height: 56,
              onPressed: _showAddMemberOptions,
            ),
            const SizedBox(height: 16),

            // Missed alerts toggle
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

            // Caregiver dashboard
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

            // Sync controls
            BigButton(
              label: sync.syncing ? l10n.syncStatusSyncing : l10n.syncNow,
              icon: Icons.sync_rounded,
              outlined: true,
              height: 56,
              onPressed: sync.syncing ? null : () => sync.syncNow(),
            ),
            const SizedBox(height: 12),

            // Disconnect
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

class _AddMemberOption extends StatelessWidget {
  const _AddMemberOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.isAdmin,
    this.onRemove,
  });

  final FamilyMember member;
  final bool isCurrentUser;
  final bool isAdmin;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleLabel = member.role == 'primary'
        ? 'Owner'
        : member.role == 'admin'
            ? 'Admin'
            : 'Member';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: member.isAdmin
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Text(
            member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
            style: theme.textTheme.titleMedium?.copyWith(
              color: member.isAdmin
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        title: Text(
          isCurrentUser ? '${member.name} (You)' : member.name,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          roleLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: member.isAdmin
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: member.isAdmin ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: (isAdmin && !isCurrentUser && onRemove != null)
            ? IconButton(
                icon: Icon(
                  Icons.remove_circle_outline_rounded,
                  color: theme.colorScheme.error,
                ),
                tooltip: 'Remove',
                onPressed: onRemove,
              )
            : null,
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
    final color =
        sync.lastError != null ? theme.missedColor : theme.successColor;
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
                            AppDateUtils.timeLabel(lastSync,
                                Localizations.localeOf(context).languageCode),
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
