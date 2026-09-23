import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/healthcare/appointment.dart';
import '../../data/repositories/appointment_repository.dart';
import 'healthcare_format.dart';
import 'slot_picker_screen.dart';
import 'widgets/healthcare_widgets.dart';

/// One appointment: when, where, with whom, its live status, its queue
/// ticket, and only the actions the backend state actually allows.
class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.organizationId,
    required this.organizationName,
    required this.appointmentId,
    this.locationName,
    this.doctorName,
  });

  final String organizationId;
  final String organizationName;
  final String appointmentId;
  final String? locationName;
  final String? doctorName;

  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  Future<Appointment> _load() {
    return context.read<AppointmentRepository>().appointment(
      organizationId: widget.organizationId,
      appointmentId: widget.appointmentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hcViewAppointment)),
      body: HcAsyncView<Appointment>(
        load: _load,
        builder: (context, appointment, reload) {
          final theme = Theme.of(context);
          final locale = Localizations.localeOf(context).languageCode;
          final relative = HealthcareFormat.relativeToNow(
            appointment.scheduledStart,
            l10n,
          );
          final queue = appointment.queueEntry;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Row(
                children: [
                  HcStatusChip.forAppointment(appointment.status, l10n),
                  const Spacer(),
                  Text(
                    '${l10n.hcBookingReferenceLabel} '
                    '${HealthcareFormat.reference(appointment.id)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                appointment.doctorName ?? widget.doctorName ?? '',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(widget.organizationName, style: theme.textTheme.bodyLarge),
              if (widget.locationName != null)
                Text(
                  widget.locationName!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Row(
                        label: l10n.hcWhen,
                        value:
                            '${HealthcareFormat.dayLong(appointment.scheduledStart, appointment.timezone, locale)}\n'
                            '${HealthcareFormat.time(appointment.scheduledStart, appointment.timezone, locale)}',
                      ),
                      if (relative != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          relative,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const Divider(height: 24),
                      _Row(
                        label: l10n.hcWhere,
                        value: widget.locationName == null
                            ? widget.organizationName
                            : '${widget.organizationName}\n${widget.locationName}',
                      ),
                      if (appointment.doctorName != null) ...[
                        const Divider(height: 24),
                        _Row(
                          label: l10n.hcDoctorLabel,
                          value: appointment.doctorName!,
                        ),
                      ],
                      if (appointment.reason != null) ...[
                        const Divider(height: 24),
                        _Row(
                          label: l10n.hcReasonLabel,
                          value: appointment.reason!,
                        ),
                      ],
                      if (appointment.notes != null) ...[
                        const Divider(height: 24),
                        _Row(
                          label: l10n.hcNotesLabel,
                          value: appointment.notes!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (queue != null) ...[
                const SizedBox(height: 24),
                HcSectionHeader(title: l10n.hcQueueTitle),
                _QueueCard(entry: queue, l10n: l10n),
              ] else if (appointment.status == AppointmentStatus.confirmed ||
                  appointment.status == AppointmentStatus.checkedIn) ...[
                const SizedBox(height: 20),
                Text(
                  l10n.hcQueueCheckInNote,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (appointment.status == AppointmentStatus.cancelled) ...[
                const SizedBox(height: 20),
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      appointment.cancellationReason ?? l10n.hcStatusCancelled,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              if (appointment.status.canReschedule)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _reschedule(appointment, reload),
                    icon: const Icon(Icons.event_repeat_rounded),
                    label: Text(l10n.hcRescheduleAction),
                  ),
                ),
              if (appointment.status.canCancel) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => _cancel(appointment, reload),
                    icon: const Icon(Icons.cancel_rounded),
                    label: Text(l10n.hcCancelAppointment),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _cancel(Appointment appointment, VoidCallback reload) async {
    final l10n = AppLocalizations.of(context);
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final repository = context.read<AppointmentRepository>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.hcCancelConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${appointment.doctorName ?? ''}\n'
              '${HealthcareFormat.dayShort(appointment.scheduledStart, appointment.timezone, Localizations.localeOf(context).languageCode)} · '
              '${HealthcareFormat.time(appointment.scheduledStart, appointment.timezone, Localizations.localeOf(context).languageCode)}',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: l10n.hcCancelReasonHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.hcKeepAppointment),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.hcCancelAppointment),
          ),
        ],
      ),
    );
    final reason = reasonController.text;
    reasonController.dispose();
    if (confirmed != true || !mounted) return;

    try {
      await repository.cancel(
        organizationId: appointment.organizationId,
        appointmentId: appointment.id,
        reason: reason,
      );
      if (!mounted) return;
      reload();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.hcAppointmentCancelled)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            e.code == 'OUTSIDE_CANCELLATION_WINDOW'
                ? l10n.hcCancelConfirmTitle
                : l10n.hcLoadFailedTitle,
          ),
          // The backend states the clinic's own cancellation window.
          content: Text(e.message),
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

  Future<void> _reschedule(Appointment appointment, VoidCallback reload) async {
    final doctorId = appointment.doctorId;
    if (doctorId == null) return;

    final moved = await Navigator.of(context).push<Appointment>(
      MaterialPageRoute<Appointment>(
        builder: (_) => SlotPickerScreen(
          doctorId: doctorId,
          doctorName: appointment.doctorName ?? widget.doctorName ?? '',
          organizationId: appointment.organizationId,
          organizationName: widget.organizationName,
          reschedule: RescheduleRequest(
            organizationId: appointment.organizationId,
            appointmentId: appointment.id,
          ),
        ),
      ),
    );
    if (moved != null && mounted) reload();
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.entry, required this.l10n});

  final QueueEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ahead = (entry.position ?? 1) - 1;

    final stateText = entry.isCalled
        ? l10n.hcQueueCalled
        : entry.isInConsultation
        ? l10n.hcQueueInConsultation
        : entry.isDone
        ? l10n.hcQueueFinished
        : ahead <= 0
        ? l10n.hcQueueYouAreNext
        : l10n.hcQueueAhead(ahead);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.confirmation_number_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.hcQueueToken(entry.tokenNumber),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(stateText, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            HcStatusChip(
              label: HealthcareFormat.queueStateLabel(entry.state, l10n),
              tone: entry.isCalled || entry.isInConsultation
                  ? HcTone.positive
                  : HcTone.pending,
            ),
          ],
        ),
      ),
    );
  }
}
