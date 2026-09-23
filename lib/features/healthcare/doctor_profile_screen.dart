import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../data/models/healthcare/clinic_location.dart';
import '../../data/models/healthcare/doctor.dart';
import '../../data/repositories/healthcare_repository.dart';
import 'healthcare_format.dart';
import 'slot_picker_screen.dart';
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
      appBar: AppBar(
        title: Text(organizationName ?? l10n.hcDoctorsTitle),
      ),
      body: HcAsyncView<DoctorDetail>(
        load: () => repository.doctorById(doctorId),
        builder: (context, doctor, reload) {
          final fee = HealthcareFormat.fee(doctor.consultationFeeMinor);
          final theme = Theme.of(context);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Photo(url: doctor.photoUrl),
                  const SizedBox(width: 16),
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
                          const SizedBox(height: 4),
                          Text(
                            doctor.specialty!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (fee != null) ...[
                          const SizedBox(height: 8),
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SlotPickerScreen(
                        doctorId: doctor.id,
                        doctorName: doctor.displayName,
                        organizationId: doctor.organization.id,
                        organizationName: doctor.organization.name,
                        branch: branch,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.event_available_rounded),
                  label: Text(l10n.hcBookAppointment),
                ),
              ),
              const SizedBox(height: 24),
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
                const SizedBox(height: 24),
                HcSectionHeader(title: l10n.hcAbout),
                Text(doctor.bio!),
              ],
              if (doctor.organization.locations.isNotEmpty) ...[
                const SizedBox(height: 24),
                HcSectionHeader(title: l10n.hcLocations),
                for (final location in doctor.organization.locations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.name,
                          style: theme.textTheme.titleMedium,
                        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    const SizedBox(width: 16),
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
