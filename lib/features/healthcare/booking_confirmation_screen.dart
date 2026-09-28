import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/healthcare/appointment.dart';
import 'appointment_detail_screen.dart';
import 'healthcare_format.dart';
import 'widgets/healthcare_widgets.dart';

/// Shown only after the platform accepted the booking — the status here is
/// the backend's own (`CONFIRMED`, or `REQUESTED` when the clinic confirms
/// appointments manually), never an optimistic guess.
class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({
    super.key,
    required this.appointment,
    required this.organizationName,
    required this.doctorName,
    this.branchName,
  });

  final Appointment appointment;
  final String organizationName;
  final String doctorName;
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.palette;
    final locale = Localizations.localeOf(context).languageCode;
    final isConfirmed = appointment.status == AppointmentStatus.confirmed;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxxl,
        ),
        children: [
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: palette.successContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 52,
                color: palette.onSuccessContainer,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isConfirmed
                ? l10n.hcBookingConfirmedTitle
                : l10n.hcBookingRequestedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: HcStatusChip.forAppointment(appointment.status, l10n),
          ),
          const SizedBox(height: AppSpacing.xl),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
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
                    HealthcareFormat.dayLong(
                      appointment.scheduledStart,
                      appointment.timezone,
                      locale,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    HealthcareFormat.time(
                      appointment.scheduledStart,
                      appointment.timezone,
                      locale,
                    ),
                    style: theme.textTheme.headlineSmall,
                  ),
                  const Divider(height: 24),
                  Text(
                    '${l10n.hcBookingReferenceLabel}: '
                    '${HealthcareFormat.reference(appointment.id)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isConfirmed) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              color: palette.warningContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: palette.onWarningContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(l10n.hcBookingPendingBody)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AppointmentDetailScreen(
                    organizationId: appointment.organizationId,
                    organizationName: organizationName,
                    appointmentId: appointment.id,
                    locationName: branchName,
                  ),
                ),
              ),
              icon: const Icon(Icons.event_note_rounded),
              label: Text(l10n.hcViewAppointment),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              child: Text(l10n.hcDone),
            ),
          ),
        ],
      ),
    );
  }
}
