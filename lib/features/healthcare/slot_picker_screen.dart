import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/healthcare/availability.dart';
import '../../data/models/healthcare/clinic_location.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../data/repositories/healthcare_repository.dart';
import 'booking_screen.dart';
import 'healthcare_format.dart';
import 'widgets/healthcare_widgets.dart';

/// Pick a day, then one of the **clinic's own** open slots.
///
/// Availability is never computed here: every time shown comes from
/// `/api/public/doctors/:id/slots`, which already excludes booked slots,
/// times inside the clinic's booking lead time, and anything outside the
/// doctor's published availability.
class SlotPickerScreen extends StatefulWidget {
  const SlotPickerScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.organizationId,
    required this.organizationName,
    this.branch,
    this.reschedule,
  });

  final String doctorId;
  final String doctorName;
  final String organizationId;
  final String organizationName;
  final ClinicLocation? branch;

  /// When set, picking a slot **moves** this existing appointment instead of
  /// creating a new one. The replacement appointment is returned to whoever
  /// pushed this screen.
  final RescheduleRequest? reschedule;

  @override
  State<SlotPickerScreen> createState() => _SlotPickerScreenState();
}

/// Identifies the appointment a slot picker should reschedule.
class RescheduleRequest {
  const RescheduleRequest({
    required this.organizationId,
    required this.appointmentId,
  });

  final String organizationId;
  final String appointmentId;
}

class _SlotPickerScreenState extends State<SlotPickerScreen> {
  static const int _daysAhead = 14;

  late DateTime _selectedDay;
  late Future<DoctorAvailability> _future;
  AvailabilitySlot? _selectedSlot;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _future = _load();
  }

  Future<DoctorAvailability> _load() {
    return context.read<HealthcareRepository>().doctorAvailability(
      widget.doctorId,
      date: _selectedDay,
    );
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = day;
      _selectedSlot = null;
      _future = _load();
    });
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.doctorName)),
      body: FutureBuilder<DoctorAvailability>(
        future: _future,
        builder: (context, snapshot) {
          final availability = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                widget.organizationName,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (widget.branch != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${l10n.hcBranch}: ${widget.branch!.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              HcSectionHeader(title: l10n.hcSelectDateTitle),
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _daysAhead,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final day = DateTime.now().add(Duration(days: index));
                    final normalized = DateTime(day.year, day.month, day.day);
                    final selected = normalized == _selectedDay;
                    return _DayChip(
                      day: normalized,
                      selected: selected,
                      locale: Localizations.localeOf(context).languageCode,
                      l10n: l10n,
                      onTap: () => _selectDay(normalized),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              HcSectionHeader(title: l10n.hcSelectTimeTitle),
              if (availability != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    l10n.hcClinicTimeNote(availability.timezone),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const HcSkeletonList(rows: 2, rowHeight: 56)
              else if (snapshot.hasError)
                HcErrorView(
                  title: l10n.hcSlotsLoadFailed,
                  body: l10n.hcNoSlotsBody,
                  onRetry: _retry,
                )
              else if (availability == null || availability.slots.isEmpty)
                HcEmptyView(
                  icon: Icons.event_busy_rounded,
                  title: l10n.hcNoSlotsTitle,
                  body: l10n.hcNoSlotsBody,
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final slot in availability.slots)
                      _SlotChip(
                        label: HealthcareFormat.time(
                          slot.start,
                          availability.timezone,
                          Localizations.localeOf(context).languageCode,
                        ),
                        selected: _selectedSlot?.start == slot.start,
                        onTap: () => setState(() => _selectedSlot = slot),
                      ),
                  ],
                ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedSlot == null ||
                          availability == null ||
                          _submitting
                      ? null
                      : () => _continue(availability),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.hcContinue),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _continue(DoctorAvailability availability) async {
    final slot = _selectedSlot;
    if (slot == null) return;

    final reschedule = widget.reschedule;
    if (reschedule != null) {
      await _confirmReschedule(reschedule, availability, slot);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingScreen(
          organizationId: widget.organizationId,
          organizationName: widget.organizationName,
          doctorId: widget.doctorId,
          doctorName: widget.doctorName,
          branch: widget.branch,
          slot: slot,
          timezone: availability.timezone,
          durationMinutes: availability.durationMinutes,
        ),
      ),
    );
  }

  /// Asks first, then asks the backend to move the appointment — the local
  /// date/time is never changed on its own.
  Future<void> _confirmReschedule(
    RescheduleRequest request,
    DoctorAvailability availability,
    AvailabilitySlot slot,
  ) async {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repository = context.read<AppointmentRepository>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.hcRescheduleTitle),
        content: Text(
          '${HealthcareFormat.dayLong(slot.start, availability.timezone, locale)}\n'
          '${HealthcareFormat.time(slot.start, availability.timezone, locale)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.hcKeepAppointment),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.hcConfirmBooking),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      final moved = await repository.reschedule(
        organizationId: request.organizationId,
        appointmentId: request.appointmentId,
        scheduledStart: slot.start,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      navigator.pop(moved);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.hcRescheduledMessage)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            e.isSlotTaken ? l10n.hcSlotTakenTitle : l10n.hcLoadFailedTitle,
          ),
          content: Text(e.isSlotTaken ? l10n.hcSlotTakenBody : e.message),
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.locale,
    required this.l10n,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final String locale;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final difference = day.difference(today).inDays;
    final top = difference == 0
        ? l10n.hcRelToday
        : difference == 1
        ? l10n.hcRelTomorrow
        : HealthcareFormat.dayShort(day, null, locale);
    final bottom = difference == 0 || difference == 1
        ? HealthcareFormat.dayShort(day, null, locale)
        : '';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              top,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
            if (bottom.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                bottom,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    );
  }
}
