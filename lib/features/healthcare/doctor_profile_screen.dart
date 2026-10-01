import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/healthcare/clinic_location.dart';
import '../../data/models/healthcare/doctor.dart';
import '../../data/models/healthcare/token.dart';
import '../../data/repositories/healthcare_repository.dart';
import '../widgets/app_buttons.dart';
import 'healthcare_format.dart';
import 'slot_picker_screen.dart';
import 'token_booking_screen.dart';
import 'widgets/healthcare_widgets.dart';

/// The public profile of one doctor, as published by their clinic.
class DoctorProfileScreen extends StatelessWidget {
  const DoctorProfileScreen({
    super.key,
    required this.doctorId,
    this.organizationName,
    this.branch,
  });

  final String doctorId;

  /// Shown while the profile loads, so the screen is never blank.
  final String? organizationName;

  /// The branch the patient picked at the clinic, carried into booking.
  final ClinicLocation? branch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.read<HealthcareRepository>();

    return Scaffold(
      appBar: AppBar(title: Text(organizationName ?? l10n.hcDoctorsTitle)),
      body: HcAsyncView<DoctorDetail>(
        load: () => repository.doctorById(doctorId),
        builder: (context, doctor, reload) {
          final fee = HealthcareFormat.fee(doctor.consultationFeeMinor);
          final theme = Theme.of(context);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Photo(url: doctor.photoUrl),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.displayName,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (doctor.specialty != null) ...[
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            doctor.specialty!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (fee != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.hcConsultationFee(fee),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (doctor.bookingMode.offersTokens) ...[
                _TodaysTokenCard(doctor: doctor, branchId: branch?.id),
                if (doctor.bookingMode.offersSlots) ...[
                  const SizedBox(height: AppSpacing.lg),
                  HcSectionHeader(title: l10n.hcOrScheduled),
                ],
              ],
              if (doctor.bookingMode.offersSlots)
                AppButton(
                  label: l10n.hcBookAppointment,
                  icon: Icons.event_available_rounded,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SlotPickerScreen(
                        doctorId: doctor.id,
                        doctorName: doctor.displayName,
                        organizationId: doctor.organization.id,
                        organizationName: doctor.organization.name,
                        branch: branch,
                        appointmentTypes: doctor.organization.appointmentTypes,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xl),
              _DetailCard(
                rows: [
                  if (doctor.qualifications != null)
                    (l10n.hcQualifications, doctor.qualifications!),
                  if (doctor.yearsOfExperience != null &&
                      doctor.yearsOfExperience! > 0)
                    (l10n.hcExperience(doctor.yearsOfExperience!), null),
                  if (doctor.languages.isNotEmpty)
                    (l10n.hcLanguages, doctor.languages.join(', ')),
                  if (doctor.registrationNumber != null)
                    (l10n.hcRegistration, doctor.registrationNumber!),
                  (l10n.hcBranch, branch?.name ?? doctor.organization.name),
                ],
              ),
              if (doctor.bio != null) ...[
                const SizedBox(height: AppSpacing.xl),
                HcSectionHeader(title: l10n.hcAbout),
                Text(doctor.bio!),
              ],
              if (doctor.organization.locations.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xl),
                HcSectionHeader(title: l10n.hcLocations),
                for (final location in doctor.organization.locations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(location.name, style: theme.textTheme.titleMedium),
                        if (location.shortAddress.isNotEmpty)
                          Text(
                            location.shortAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_rounded,
        size: 44,
        color: theme.colorScheme.primary,
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return ClipOval(
      child: Image.network(
        url!,
        width: 88,
        height: 88,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});

  /// (label, value) — a row with a null value renders label only.
  final List<(String, String?)> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        rows[i].$1,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 2,
                      child: Text(
                        rows[i].$2 ?? '',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Today's token" — state comes from the server's window for the clinic's
/// own timezone, never from this device's clock. Re-read on every open and
/// on tap of the refresh icon, since it flips open at a configured minute.
class _TodaysTokenCard extends StatefulWidget {
  const _TodaysTokenCard({required this.doctor, this.branchId});

  final DoctorDetail doctor;
  final String? branchId;

  @override
  State<_TodaysTokenCard> createState() => _TodaysTokenCardState();
}

class _TodaysTokenCardState extends State<_TodaysTokenCard> {
  late Future<TokenWindow> _window;

  @override
  void initState() {
    super.initState();
    _window = _load();
  }

  Future<TokenWindow> _load() =>
      context.read<HealthcareRepository>().tokenWindow(widget.doctor.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: FutureBuilder<TokenWindow>(
          future: _window,
          builder: (context, snapshot) {
            final window = snapshot.data;
            final String line;
            if (window == null) {
              line = snapshot.hasError ? l10n.hcLoadFailedTitle : '…';
            } else if (window.bookable) {
              line = l10n.hcTokenOpenNow;
            } else if (window.isNotYetOpen) {
              line = l10n.hcTokenOpensAt(window.opensAt);
            } else if (window.isLimitReached) {
              line = l10n.hcTokenLimitReached;
            } else {
              line = l10n.hcTokenClosed;
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.confirmation_number_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.hcTodaysToken,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.hcRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: () => setState(() => _window = _load()),
                    ),
                  ],
                ),
                Text(line, style: theme.textTheme.bodyLarge),
                if (window != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    l10n.hcTokenWindowTimes(
                      window.opensAt,
                      window.closesAt,
                      window.queueStartAt,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: window != null && window.isNotYetOpen
                      ? l10n.hcTokenOpensAtButton(window.opensAt)
                      : l10n.hcBookTodaysToken,
                  icon: Icons.confirmation_number_outlined,
                  onPressed: window == null || !window.bookable
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TokenBookingScreen(
                              organizationId: widget.doctor.organization.id,
                              organizationName: widget.doctor.organization.name,
                              doctorId: widget.doctor.id,
                              doctorName: widget.doctor.displayName,
                              window: window,
                              locationId: widget.branchId,
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
