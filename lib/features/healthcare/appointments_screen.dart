import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../data/models/healthcare/appointment.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../services/platform_auth_service.dart';
import 'appointment_detail_screen.dart';
import 'healthcare_format.dart';
import 'platform_sign_in_screen.dart';
import 'widgets/healthcare_widgets.dart';

/// Every appointment this patient has with any clinic on the platform,
/// grouped the way a patient thinks about them: what's coming, what's done,
/// what was cancelled.
class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  Future<List<PatientAppointment>> _load() {
    return context.read<AppointmentRepository>().myAppointments();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = context.watch<PlatformAuthService>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.hcMyAppointments),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.hcTabUpcoming),
              Tab(text: l10n.hcTabPast),
              Tab(text: l10n.hcTabCancelled),
            ],
          ),
        ),
        body: !account.isSignedIn
            ? HcEmptyView(
                icon: Icons.lock_outline_rounded,
                title: l10n.hcAppointmentsSignInTitle,
                body: l10n.hcAppointmentsSignInBody,
                actionLabel: l10n.hcSignIn,
                onAction: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PlatformSignInScreen(),
                  ),
                ),
              )
            : HcAsyncView<List<PatientAppointment>>(
                load: _load,
                builder: (context, appointments, reload) {
                  final upcoming = appointments
                      .where((row) => row.appointment.status.isUpcoming)
                      .toList()
                    ..sort(
                      (a, b) => a.appointment.scheduledStart.compareTo(
                        b.appointment.scheduledStart,
                      ),
                    );
                  final past = appointments
                      .where(
                        (row) =>
                            row.appointment.status ==
                                AppointmentStatus.completed ||
                            row.appointment.status == AppointmentStatus.noShow ||
                            row.appointment.status ==
                                AppointmentStatus.rescheduled,
                      )
                      .toList();
                  final cancelled = appointments
                      .where((row) => row.appointment.status.isCancelled)
                      .toList();

                  return TabBarView(
                    children: [
                      _AppointmentsList(
                        rows: upcoming,
                        emptyTitle: l10n.hcNoUpcomingTitle,
                        emptyBody: l10n.hcNoUpcomingBody,
                        onRefresh: () async => reload(),
                      ),
                      _AppointmentsList(
                        rows: past,
                        emptyTitle: l10n.hcNoPastTitle,
                        emptyBody: l10n.hcNoPastBody,
                        onRefresh: () async => reload(),
                      ),
                      _AppointmentsList(
                        rows: cancelled,
                        emptyTitle: l10n.hcNoCancelledTitle,
                        emptyBody: l10n.hcNoCancelledBody,
                        onRefresh: () async => reload(),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  const _AppointmentsList({
    required this.rows,
    required this.emptyTitle,
    required this.emptyBody,
    required this.onRefresh,
  });

  final List<PatientAppointment> rows;
  final String emptyTitle;
  final String emptyBody;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          children: [
            HcEmptyView(
              icon: Icons.event_available_rounded,
              title: emptyTitle,
              body: emptyBody,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: rows.length,
        itemBuilder: (context, index) => _AppointmentTile(
          row: rows[index],
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AppointmentDetailScreen(
                organizationId: rows[index].organization.id,
                organizationName: rows[index].organization.name,
                appointmentId: rows[index].appointment.id,
                locationName: rows[index].location?.name,
                doctorName: rows[index].appointment.doctorName,
              ),
            ),
          ),
          l10n: l10n,
        ),
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile({
    required this.row,
    required this.onTap,
    required this.l10n,
  });

  final PatientAppointment row;
  final VoidCallback onTap;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final appointment = row.appointment;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      appointment.doctorName ?? row.organization.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  HcStatusChip.forAppointment(appointment.status, l10n),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                row.location == null
                    ? row.organization.name
                    : '${row.organization.name} · ${row.location!.name}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.event_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${HealthcareFormat.dayMedium(appointment.scheduledStart, appointment.timezone, locale)}'
                      ' · '
                      '${HealthcareFormat.time(appointment.scheduledStart, appointment.timezone, locale)}',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 26,
                    color: theme.colorScheme.outline,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
