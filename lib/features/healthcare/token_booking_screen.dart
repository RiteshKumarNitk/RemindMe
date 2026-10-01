import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/healthcare/token.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../services/platform_auth_service.dart';
import '../widgets/app_buttons.dart';
import 'appointment_detail_screen.dart';
import 'platform_sign_in_screen.dart';
import 'widgets/healthcare_widgets.dart';

/// Confirms today's same-day token: sign in → details → confirm.
///
/// No date is chosen or sent. The server picks "today" in the clinic's
/// timezone, enforces the booking window and daily cap, and hands back the
/// existing token if the patient already has one — the app adds no rules.
class TokenBookingScreen extends StatefulWidget {
  const TokenBookingScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.doctorId,
    required this.doctorName,
    required this.window,
    this.locationId,
  });

  final String organizationId;
  final String organizationName;
  final String doctorId;
  final String doctorName;

  /// The window the profile screen showed — for the summary only; the server
  /// re-checks it at booking time.
  final TokenWindow window;
  final String? locationId;

  @override
  State<TokenBookingScreen> createState() => _TokenBookingScreenState();
}

class _TokenBookingScreenState extends State<TokenBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _reason = TextEditingController();
  bool _submitting = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = context.watch<PlatformAuthService>();
    final window = widget.window;

    if (account.isSignedIn && !_prefilled) {
      _prefilled = true;
      final user = account.user;
      if (user != null) {
        _firstName.text = user.firstName;
        _lastName.text = user.lastName;
        _phone.text = user.phone ?? '';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hcTodaysToken)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.doctorName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    widget.organizationName,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const Divider(height: 24),
                  Text(window.date, style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.hcTokenWindowTimes(
                      window.opensAt,
                      window.closesAt,
                      window.queueStartAt,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.hcTokenIntro, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!account.isSignedIn)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hcSignInTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(l10n.hcSignInBody),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      label: l10n.hcSignIn,
                      icon: Icons.login_rounded,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PlatformSignInScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HcSectionHeader(title: l10n.hcYourDetailsTitle),
                  TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l10n.hcFirstName),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? l10n.hcFieldRequired : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: l10n.hcLastName),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? l10n.hcFieldRequired : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: '${l10n.hcPhone} · ${l10n.hcOptional}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _reason,
                    maxLength: 200,
                    decoration: InputDecoration(
                      labelText: '${l10n.hcReasonTitle} · ${l10n.hcOptional}',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: l10n.hcConfirmToken,
                    icon: Icons.confirmation_number_rounded,
                    onPressed: _submit,
                    busy: _submitting,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final repository = context.read<AppointmentRepository>();

    setState(() => _submitting = true);
    try {
      final booking = await repository.bookToken(
        organizationId: widget.organizationId,
        doctorId: widget.doctorId,
        locationId: widget.locationId,
        reason: _reason.text,
        patient: PatientDetails(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        ),
      );
      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => AppointmentDetailScreen(
            organizationId: widget.organizationId,
            organizationName: widget.organizationName,
            appointmentId: booking.appointmentId,
            doctorName: widget.doctorName,
            banner: booking.reused
                ? l10n.hcTokenAlreadyHave
                : l10n.hcTokenBooked,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final expired = e.isUnauthenticated || e.sessionExpired;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            expired ? l10n.hcSessionExpired : l10n.hcBookingFailedTitle,
          ),
          // TOKEN_BOOKING_NOT_OPEN / _CLOSED / TOKEN_LIMIT_REACHED all carry
          // the server's own sentence with the clinic's real times.
          content: Text(expired ? l10n.hcSignInBody : e.message),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.hcDone),
            ),
          ],
        ),
      );
    }
  }
}
