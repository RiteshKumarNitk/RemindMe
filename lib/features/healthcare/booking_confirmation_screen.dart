import 'package:flutter/material.dart';

import '../../core/localization/generated/app_localizations.dart';
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
    final locale = Localizations.localeOf(context).languageCode;
    final isConfirmed = appointment.status == AppointmentStatus.confirmed;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFDCF2E1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 52,
                color: Color(0xFF14532D),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isConfirmed
                ? l10n.hcBookingConfirmedTitle
                : l10n.hcBookingRequestedTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: HcStatusChip.forAppointment(appointment.status, l10n),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFFDF0D5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: Color(0xFF7A4A00)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l10n.hcBookingPendingBody)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
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
          const SizedBox(height: 12),
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
