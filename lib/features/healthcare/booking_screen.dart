import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/healthcare/appointment_type.dart';
import '../../data/models/healthcare/availability.dart';
import '../../data/models/healthcare/clinic_location.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../services/platform_auth_service.dart';
import '../widgets/app_buttons.dart';
import 'booking_confirmation_screen.dart';
import 'healthcare_format.dart';
import 'platform_sign_in_screen.dart';
import 'widgets/healthcare_widgets.dart';

/// Collects the details the clinic needs and books the chosen slot.
///
/// The first time a patient books with a clinic, the platform registers them
/// as a patient of that clinic using exactly these fields — the app never
/// invents or caches a patient record of its own.
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.doctorId,
    required this.doctorName,
    required this.slot,
    required this.timezone,
    this.branch,
    this.durationMinutes = 0,
    this.appointmentType,
  });

  final String organizationId;
  final String organizationName;
  final String doctorId;
  final String doctorName;
  final AvailabilitySlot slot;
  final String timezone;
  final ClinicLocation? branch;
  final int durationMinutes;

  /// The clinic's booking category chosen on the slot picker (request §35);
  /// null = the clinic's default visit type.
  final AppointmentTypeInfo? appointmentType;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _reason = TextEditingController();

  DateTime? _dateOfBirth;
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

    if (account.isSignedIn && !_prefilled) {
      _prefilled = true;
      final user = account.user;
      if (user != null) {
        _firstName.text = user.firstName;
        _lastName.text = user.lastName;
        _phone.text = user.phone ?? '';
      }
    }

    final locale = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hcBookAppointment)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          _SummaryCard(
            organizationName: widget.organizationName,
            branchName: widget.branch?.name,
            doctorName: widget.doctorName,
            timeLabel: HealthcareFormat.time(
              widget.slot.start,
              widget.timezone,
              locale,
            ),
            dayLabel: HealthcareFormat.dayLong(
              widget.slot.start,
              widget.timezone,
              locale,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!account.isSignedIn)
            _SignInGate(
              onSignIn: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PlatformSignInScreen(),
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
                  Text(
                    l10n.hcYourDetailsBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.hcFirstName,
                      prefixIcon: const Icon(Icons.person_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.hcFieldRequired
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l10n.hcLastName,
                      prefixIcon: const Icon(Icons.person_outline_rounded),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? l10n.hcFieldRequired
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '${l10n.hcPhone} · ${l10n.hcOptional}',
                      prefixIcon: const Icon(Icons.call_rounded),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DateOfBirthField(
                    value: _dateOfBirth,
                    onChanged: (value) =>
                        setState(() => _dateOfBirth = value),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _reason,
                    maxLines: 3,
                    maxLength: 200,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText:
                          '${l10n.hcReasonTitle} · ${l10n.hcOptional}',
                      hintText: l10n.hcReasonHint,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  AppButton(
                    label: l10n.hcConfirmBooking,
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
      final appointment = await repository.book(
        organizationId: widget.organizationId,
        doctorId: widget.doctorId,
        scheduledStart: widget.slot.start,
        locationId: widget.branch?.id,
        appointmentTypeId: widget.appointmentType?.id,
        reason: _reason.text,
        patient: PatientDetails(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          dateOfBirth: _dateOfBirth,
        ),
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BookingConfirmationScreen(
            appointment: appointment,
            organizationName: widget.organizationName,
            doctorName: widget.doctorName,
            branchName: widget.branch?.name,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showFailure(e, l10n);
    }
  }

  Future<void> _showFailure(ApiException error, AppLocalizations l10n) async {
    final slotTaken = error.isSlotTaken;
    final expired = error.isUnauthenticated || error.sessionExpired;

    final title = slotTaken
        ? l10n.hcSlotTakenTitle
        : expired
        ? l10n.hcSessionExpired
        : l10n.hcBookingFailedTitle;
    final body = slotTaken
        ? l10n.hcSlotTakenBody
        : expired
        ? l10n.hcSignInBody
        : error.message;

    final goBack = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.hcRetry),
          ),
          if (slotTaken)
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.hcKeepAppointment),
            ),
        ],
      ),
    );

    if (goBack == true && mounted) {
      // Back to the slot list so the patient can pick a fresh time.
      Navigator.of(context).pop();
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.organizationName,
    required this.branchName,
    required this.doctorName,
    required this.timeLabel,
    required this.dayLabel,
  });

  final String organizationName;
  final String? branchName;
  final String doctorName;
  final String timeLabel;
  final String dayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.hcReviewTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              doctorName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(organizationName, style: theme.textTheme.bodyLarge),
            if (branchName != null)
              Text(
                branchName!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const Divider(height: 24),
            Text(
              dayLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(timeLabel, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      borderRadius: AppRadius.controlRadius,
      onTap: () async {
        final now = DateTime.now();
        final initial = value ?? DateTime(now.year - 60, 1, 1);
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(now.year - 120),
          lastDate: now,
          helpText: l10n.hcOptional,
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: l10n.hcOptional,
          prefixIcon: const Icon(Icons.cake_rounded),
        ),
        child: Text(
          value == null
              ? l10n.hcOptional
              : HealthcareFormat.dayMedium(value!, null, Localizations.localeOf(context).languageCode),
        ),
      ),
    );
  }
}

class _SignInGate extends StatelessWidget {
  const _SignInGate({required this.onSignIn});

  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.hcSignInTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(l10n.hcSignInBody),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.hcSignIn,
              icon: Icons.login_rounded,
              onPressed: onSignIn,
            ),
          ],
        ),
      ),
    );
  }
}
