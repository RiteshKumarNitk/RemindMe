import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/repositories/appointment_repository.dart';
import '../../../services/platform_auth_service.dart';
import '../appointment_detail_screen.dart';
import '../appointments_screen.dart';
import '../healthcare_format.dart';
import '../healthcare_home_screen.dart';
import '../platform_sign_in_screen.dart';
import 'healthcare_widgets.dart';

/// The healthcare block on the medicine-first home screen.
///
/// Deliberately small: one way in to discovery, plus — only when it exists —
/// the patient's next real appointment. The medicine dashboard above it is
/// untouched by any of this.
class HomeCareSection extends StatelessWidget {
  const HomeCareSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = context.watch<PlatformAuthService>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HcSectionHeader(title: l10n.hcCareSection),
        _FindCareCard(l10n: l10n),
        const SizedBox(height: 12),
        if (account.isSignedIn)
          _NextAppointmentCard(l10n: l10n)
        else
          _SignInRow(l10n: l10n),
      ],
    );
  }
}

class _FindCareCard extends StatelessWidget {
  const _FindCareCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const HealthcareHomeScreen(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: AppRadius.controlRadius,
                ),
                child: Icon(
                  Icons.local_hospital_rounded,
                  size: 30,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hcFindTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.hcFindSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 28,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInRow extends StatelessWidget {
  const _SignInRow({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const PlatformSignInScreen(),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.event_note_rounded,
                size: 26,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.hcAppointmentsSignInTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.hcAppointmentsSignInBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The patient's next confirmed appointment, straight from the backend.
class _NextAppointmentCard extends StatefulWidget {
  const _NextAppointmentCard({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_NextAppointmentCard> createState() => _NextAppointmentCardState();
}

class _NextAppointmentCardState extends State<_NextAppointmentCard> {
  late Future<PatientAppointment?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadNext();
  }

  Future<PatientAppointment?> _loadNext() async {
    final rows = await context.read<AppointmentRepository>().myAppointments(
      includeClosed: false,
    );
    final upcoming = rows
        .where((row) => row.appointment.status.isUpcoming)
        .toList()
      ..sort(
        (a, b) => a.appointment.scheduledStart.compareTo(
          b.appointment.scheduledStart,
        ),
      );
    return upcoming.isEmpty ? null : upcoming.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return FutureBuilder<PatientAppointment?>(
      future: _future,
      builder: (context, snapshot) {
        // A failed lookup on the dashboard stays quiet — the medicine
        // reminders must not be interrupted by a clinic-network problem.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const HcSkeletonList(rows: 1, rowHeight: 96);
        }
        final row = snapshot.data;
        if (snapshot.hasError || row == null) {
          return _NoAppointmentCard(
            l10n: l10n,
            onChanged: () => setState(() => _future = _loadNext()),
          );
        }
        return _AppointmentCard(row: row, l10n: l10n);
      },
    );
  }
}

class _NoAppointmentCard extends StatelessWidget {
  const _NoAppointmentCard({required this.l10n, required this.onChanged});

  final AppLocalizations l10n;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const AppointmentsScreen()),
          );
          onChanged();
        },
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(
                Icons.event_busy_rounded,
                size: 26,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l10n.hcNoUpcomingAppointment,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 26,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.row, required this.l10n});

  final PatientAppointment row;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final appointment = row.appointment;
    final relative = HealthcareFormat.relativeToNow(
      appointment.scheduledStart,
      l10n,
    );

    return Card(
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AppointmentDetailScreen(
              organizationId: row.organization.id,
              organizationName: row.organization.name,
              appointmentId: appointment.id,
              locationName: row.location?.name,
              doctorName: appointment.doctorName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.hcUpcomingAppointment,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  HcStatusChip.forAppointment(appointment.status, l10n),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                appointment.doctorName ?? row.organization.name,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                row.organization.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${HealthcareFormat.dayMedium(appointment.scheduledStart, appointment.timezone, locale)}'
                ' · '
                '${HealthcareFormat.time(appointment.scheduledStart, appointment.timezone, locale)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (relative != null)
                Text(
                  relative,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
