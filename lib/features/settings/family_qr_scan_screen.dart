import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/sync/invitation_service.dart';
import 'family_connection_confirm_screen.dart';

/// Scans a QR code to join a family.
///
/// Handles all error cases:
///   - Camera permission not granted
///   - Invalid QR code format
///   - Expired invitation
///   - Already-used invitation
///   - Already connected to this family
///   - Scanning own QR code
///   - Network failure
class FamilyQrScanScreen extends StatefulWidget {
  const FamilyQrScanScreen({super.key});

  @override
  State<FamilyQrScanScreen> createState() => _FamilyQrScanScreenState();
}

class _FamilyQrScanScreenState extends State<FamilyQrScanScreen> {
  MobileScannerController? _controller;
  bool _scanned = false;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned || _processing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _scanned = true;
    _processCode(rawValue);
  }

  Future<void> _processCode(String rawValue) async {
    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      // Parse the QR code payload
      final invitation = InvitationData.fromQrPayload(rawValue);
      if (invitation == null) {
        setState(() {
          _error = 'Invalid QR code. This is not a DoseWise family invitation.';
          _processing = false;
          _scanned = false;
        });
        return;
      }

      final auth = context.read<AuthService>();
      final invitationService = InvitationService();

      // Validate the invitation
      final validation = await invitationService.validateInvitation(
        token: invitation.token,
        currentUid: auth.uid,
      );

      if (!validation.valid) {
        setState(() {
          _error = validation.error ?? 'Invalid invitation';
          _processing = false;
          _scanned = false;
        });
        return;
      }

      // Navigate to confirmation screen
      if (mounted) {
        final confirmed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => FamilyConnectionConfirmScreen(
              familyName: validation.creatorName ?? 'Family',
              householdCode: validation.householdCode!,
              token: invitation.token,
            ),
          ),
        );

        if (confirmed == true && mounted) {
          // Connected successfully — pop back to family sync screen
          Navigator.of(context).pop(true);
        } else {
          // User cancelled — allow scanning again
          setState(() {
            _processing = false;
            _scanned = false;
          });
        }
      }
    } catch (e) {
      developer.log('QR scan processing failed: $e', name: 'FamilyQR');
      if (mounted) {
        setState(() {
          _error = 'Failed to process QR code. Please try again.';
          _processing = false;
          _scanned = false;
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
      ),
      body: Column(
        children: [
          // Scanner area
          Expanded(
            flex: 5,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Camera preview
                MobileScanner(
                  controller: _controller!,
                  onDetect: _onDetect,
                ),

                // Scanning overlay with cutout
                CustomPaint(
                  painter: _ScannerOverlayPainter(),
                  size: Size.infinite,
                ),

                // Processing indicator
                if (_processing)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Connecting...',
                                style: theme.textTheme.titleMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom info area
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              child: _error != null
                  ? _buildErrorState(theme)
                  : _buildScanInstructions(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanInstructions(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.qr_code_scanner_rounded,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          'Point your camera at a DoseWise QR code',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Ask your family member to show their QR code from Settings → Family Sync',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 48,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 12),
        Text(
          _error!,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            setState(() {
              _error = null;
              _scanned = false;
            });
          },
          icon: const Icon(Icons.qr_code_scanner_rounded),
          label: const Text('Scan Again'),
        ),
      ],
    );
  }
}

/// Custom painter that draws a semi-transparent overlay with a cutout
/// for the scanning area.
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final scanArea = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.7,
      height: size.width * 0.7,
    );

    // Draw overlay with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(scanArea, const Radius.circular(16)),
          ),
      ),
      paint,
    );

    // Draw scan area border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRRect(
      RRect.fromRectAndRadius(scanArea, const Radius.circular(16)),
      borderPaint,
    );

    // Draw corner accents
    final accentPaint = Paint()
      ..color = const Color(0xFF3E2B64) // Purple from app theme
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 30.0;
    final corners = [
      // Top-left
      (Offset(scanArea.left, scanArea.top + cornerLength),
       Offset(scanArea.left, scanArea.top),
       Offset(scanArea.left + cornerLength, scanArea.top)),
      // Top-right
      (Offset(scanArea.right - cornerLength, scanArea.top),
       Offset(scanArea.right, scanArea.top),
       Offset(scanArea.right, scanArea.top + cornerLength)),
      // Bottom-right
      (Offset(scanArea.right, scanArea.bottom - cornerLength),
       Offset(scanArea.right, scanArea.bottom),
       Offset(scanArea.right - cornerLength, scanArea.bottom)),
      // Bottom-left
      (Offset(scanArea.left + cornerLength, scanArea.bottom),
       Offset(scanArea.left, scanArea.bottom),
       Offset(scanArea.left, scanArea.bottom - cornerLength)),
    ];

    for (final (start, corner, end) in corners) {
      canvas.drawLine(start, corner, accentPaint);
      canvas.drawLine(corner, end, accentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
