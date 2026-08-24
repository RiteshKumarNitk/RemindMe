import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
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
        content: TextField(
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

    return Scaffold(
      appBar: AppBar(title: Text(l10n.familySync)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(l10n.familySyncIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 20),
          if (sync.enabled) ...[
            _StatusCard(sync: sync, l10n: l10n),
            const SizedBox(height: 20),
            _CodeCard(sync: sync, l10n: l10n),
            const SizedBox(height: 16),
            if (sync.role == 'watcher') ...[
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
            ],
            const SizedBox(height: 8),
            BigButton(
              label: sync.syncing ? l10n.syncStatusSyncing : l10n.syncNow,
              icon: Icons.sync_rounded,
              outlined: true,
              height: 60,
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
            _RoleCard(
              icon: Icons.favorite_rounded,
              title: l10n.syncRolePrimary,
              subtitle: l10n.syncRolePrimaryDesc,
              onTap: _busy ? null : () => _enable('primary'),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              icon: Icons.volunteer_activism_rounded,
              title: l10n.syncRoleWatcher,
              subtitle: l10n.syncRoleWatcherDesc,
              onTap: _busy ? null : _askCode,
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (sync.lastError != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.onErrorContainer,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sync.lastError!.toLowerCase().contains('not configured')
                          ? l10n.syncNotConfigured
                          : l10n.syncFailed,
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
                            '${lastSync.hour.toString().padLeft(2, '0')}:'
                            '${lastSync.minute.toString().padLeft(2, '0')}',
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
