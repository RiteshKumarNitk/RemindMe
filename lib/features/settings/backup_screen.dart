import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/backup_service.dart';

/// Screen for managing backups: create, restore, and delete.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backupService = BackupService();
  List<BackupInfo> _backups = [];
  bool _loading = true;
  bool _operating = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    try {
      final backups = await _backupService.listBackups();
      if (mounted) {
        setState(() {
          _backups = backups;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load backups: $e')),
        );
      }
    }
  }

  Future<void> _createBackup() async {
    setState(() => _operating = true);
    try {
      await _backupService.createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup created successfully')),
        );
        await _loadBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _operating = false);
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will replace all current data with the backup. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _operating = true);
    try {
      final success = await _backupService.restoreBackup(backup.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Backup restored! Restart the app.' : 'Restore failed',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
    if (mounted) setState(() => _operating = false);
  }

  Future<void> _deleteBackup(BackupInfo backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup?'),
        content: Text('Delete ${backup.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _backupService.deleteBackup(backup.path);
        await _loadBackups();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Create backup card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                        theme.colorScheme.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.backup_rounded,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Create Backup',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Save all your medicines, settings, and vitals to a file',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _operating ? null : _createBackup,
                          icon: _operating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(_operating ? 'Creating...' : 'Create Backup'),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Existing backups
                Text(
                  'Existing Backups (${_backups.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                if (_backups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'No backups yet. Create one to protect your data.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  for (final backup in _backups)
                    _BackupTile(
                      backup: backup,
                      onRestore: () => _restoreBackup(backup),
                      onDelete: () => _deleteBackup(backup),
                    ),

                const SizedBox(height: 24),

                // Info card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Backups include your medicines, dose history, '
                          'settings, and vitals. Keep a copy in a safe place '
                          'like Google Drive or email it to yourself.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.backup,
    required this.onRestore,
    required this.onDelete,
  });

  final BackupInfo backup;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr = DateFormat.yMMMd().add_jm().format(backup.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.description_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateStr · ${backup.sizeLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRestore,
            icon: Icon(
              Icons.restore_rounded,
              color: theme.colorScheme.primary,
            ),
            tooltip: 'Restore',
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: theme.colorScheme.outline,
              size: 20,
            ),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}
