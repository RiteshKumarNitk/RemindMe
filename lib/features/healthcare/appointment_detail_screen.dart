import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/healthcare/appointment.dart';
import '../../data/models/healthcare/token.dart';
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
    this.banner,
  });

  /// One-off confirmation shown at the top (e.g. "Your token is booked.").
  final String? banner;

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
  final _tokenCard = GlobalKey<_LiveTokenCardState>();

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
          // A token has no booked time — its scheduledStart is the queue-start
          // anchor — so no "in 2 hours" countdown for it.
          final relative = appointment.isToken
              ? null
              : HealthcareFormat.relativeToNow(
                  appointment.scheduledStart,
                  l10n,
                );
          final queue = appointment.queueEntry;
          final day = HealthcareFormat.dayLong(
            appointment.scheduledStart,
            appointment.timezone,
            locale,
          );
          final time = HealthcareFormat.time(
            appointment.scheduledStart,
            appointment.timezone,
            locale,
          );
          final whenValue = appointment.isToken
              ? l10n.hcTokenDay(day, time)
              : '$day\n$time';

          return RefreshIndicator(
            // With a token, refresh just the live card — reloading the whole
            // screen would flash the skeleton and rebuild the card (a second
            // request). Without one, reload the appointment.
            onRefresh: () async {
              final card = _tokenCard.currentState;
              if (card != null) {
                await card.refresh();
              } else {
                reload();
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xxxl,
              ),
              children: [
                if (widget.banner != null) ...[
                  HcStatusChip(label: widget.banner!, tone: HcTone.positive),
                  const SizedBox(height: AppSpacing.md),
                ],
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
                const SizedBox(height: AppSpacing.md),
                Text(
                  appointment.doctorName ?? widget.doctorName ?? '',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(widget.organizationName, style: theme.textTheme.bodyLarge),
                if (widget.locationName != null)
                  Text(
                    widget.locationName!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(label: l10n.hcWhen, value: whenValue),
                        if (relative != null) ...[
                          const SizedBox(height: AppSpacing.xxs + 2),
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
                  const SizedBox(height: AppSpacing.xl),
                  HcSectionHeader(title: l10n.hcQueueTitle),
                  _LiveTokenCard(
                    key: _tokenCard,
                    appointmentId: appointment.id,
                    fallback: queue,
                  ),
                ] else if (appointment.status == AppointmentStatus.confirmed ||
                    appointment.status == AppointmentStatus.checkedIn) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.hcQueueCheckInNote,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (appointment.status == AppointmentStatus.cancelled) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        appointment.cancellationReason ??
                            l10n.hcStatusCancelled,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
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
                  const SizedBox(height: AppSpacing.sm),
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
            ),
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
            const SizedBox(height: AppSpacing.md),
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
        const SizedBox(height: AppSpacing.xxs - 2),
        Text(value, style: theme.textTheme.bodyLarge),
      ],
    );
  }
}

/// The patient's token, read live from `/patient/token-status` — the same
/// queue rows reception works from. "Ahead" and "now serving" are the
/// server's counts; nothing here is estimated. Polls while the token is
/// still in play and stops once it is finished.
class _LiveTokenCard extends StatefulWidget {
  const _LiveTokenCard({
    super.key,
    required this.appointmentId,
    required this.fallback,
  });

  final String appointmentId;

  /// Shown until (or if) the live status can't be loaded.
  final QueueEntry fallback;

  @override
  State<_LiveTokenCard> createState() => _LiveTokenCardState();
}

class _LiveTokenCardState extends State<_LiveTokenCard> {
  static const _pollEvery = Duration(seconds: 20);

  TokenStatus? _status;
  Timer? _timer;
  bool _inFlight = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() async {
    // A pull-to-refresh landing while a poll is in flight must not double up.
    if (_inFlight) return;
    _inFlight = true;
    try {
      final status = await context.read<AppointmentRepository>().tokenStatus(
        widget.appointmentId,
      );
      if (!mounted) return;
      setState(() => _status = status);
      _timer?.cancel();
      if (status.isLive) _timer = Timer(_pollEvery, refresh);
    } on ApiException {
      // Keep the last known (or fallback) ticket and try again on the next
      // tick — a dropped request on a flaky network must not stop updates.
      if (mounted && (_status?.isLive ?? true)) {
        _timer?.cancel();
        _timer = Timer(_pollEvery, refresh);
      }
    } finally {
      _inFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = _status;
    final token = status?.tokenNumber ?? widget.fallback.tokenNumber;
    // A cancelled token's entry is parked as SKIPPED; show the real status.
    final state = status == null
        ? widget.fallback.state
        : status.isWithdrawn
        ? status.appointmentStatus
        : status.state;

    final tone = switch (state) {
      'CALLED' || 'IN_CONSULTATION' || 'COMPLETED' => HcTone.positive,
      'HOLD' || 'SKIPPED' => HcTone.pending,
      'NO_SHOW' => HcTone.negative,
      _ => HcTone.neutral,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.confirmation_number_rounded,
                  color: theme.colorScheme.primary,
                  size: AppSizes.iconXl - 4,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.hcYourToken(token),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            HcStatusChip(
              label: HealthcareFormat.queueStateLabel(state, l10n),
              tone: tone,
            ),
            if (status != null) ...[
              const SizedBox(height: AppSpacing.sm),
              if (status.isWaiting)
                Text(
                  status.ahead <= 0
                      ? l10n.hcQueueYouAreNext
                      : l10n.hcQueueAhead(status.ahead),
                  style: theme.textTheme.titleMedium,
                ),
              if (status.isWaiting && status.nowServingToken != null)
                Text(
                  l10n.hcNowServing(status.nowServingToken!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              // What to do next — written by the server for this exact state.
              Text(status.advice, style: theme.textTheme.bodyLarge),
              if (status.isLive) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.hcTokenRefreshNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
