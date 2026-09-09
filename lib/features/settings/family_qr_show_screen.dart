import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/sync/invitation_service.dart';
import '../../services/sync/sync_service.dart';

/// Displays a QR code that family members can scan to connect.
///
/// The QR code contains a secure, short-lived invitation token — NOT any
/// personal information. The token expires after 24 hours and can only
/// be used once.
class FamilyQrShowScreen extends StatefulWidget {
  const FamilyQrShowScreen({super.key});

  @override
  State<FamilyQrShowScreen> createState() => _FamilyQrShowScreenState();
}

class _FamilyQrShowScreenState extends State<FamilyQrShowScreen> {
  InvitationData? _invitation;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createInvitation();
  }

  Future<void> _createInvitation() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final sync = context.read<SyncService>();
      final invitationService = InvitationService();

      if (auth.uid.isEmpty) {
        throw StateError('Please sign in to create a family invitation.');
      }

      if (!sync.enabled) {
        throw StateError('Family sync is not enabled. Create a family code first.');
      }

      final invitation = await invitationService.createInvitation(
        householdCode: sync.householdCode,
        creatorUid: auth.uid,
        creatorName: auth.displayName.isNotEmpty ? auth.displayName : 'Family Member',
      );

      if (mounted) {
        setState(() {
          _invitation = invitation;
          _loading = false;
        });
      }
    } catch (e) {
      developer.log('Failed to create invitation: $e', name: 'FamilyQR');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(l10n.familySync),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Generate new QR',
            onPressed: _createInvitation,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError(theme)
              : _buildQrContent(theme),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _createInvitation,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrContent(ThemeData theme) {
    final l10n = AppLocalizations.of(context);
    final invitation = _invitation!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        // Header
        Text(
          'Show My QR Code',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Let family members scan this code to connect with you.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),

        // QR Code card
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                QrImageView(
                  data: invitation.toQrPayload(),
                  version: QrVersions.auto,
                  size: 260,
                  backgroundColor: Colors.white,

                ),
                const SizedBox(height: 24),
                Text(
                  'Scan to Connect',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invitation.creatorName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Security info
        Card(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Security Info',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _SecurityItem(
                  icon: Icons.access_time_rounded,
                  text: 'Expires in 24 hours',
                ),
                const SizedBox(height: 4),
                _SecurityItem(
                  icon: Icons.looks_one_rounded,
                  text: 'Single use — can only be scanned once',
                ),
                const SizedBox(height: 4),
                _SecurityItem(
                  icon: Icons.lock_rounded,
                  text: 'No personal info in QR code',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Share button
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () async {
              await Share.share(
                'Connect with me on DoseWise!\n\n'
                'Open the app → Settings → Family Sync → Scan QR Code\n'
                'then point your camera at my screen.',
                subject: 'DoseWise Family Connection',
              );
            },
            icon: const Icon(Icons.share_rounded),
            label: Text(l10n.familySync),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityItem extends StatelessWidget {
  const _SecurityItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
