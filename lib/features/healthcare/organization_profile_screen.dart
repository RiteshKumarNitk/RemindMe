import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../data/models/healthcare/clinic_location.dart';
import '../../data/models/healthcare/doctor.dart';
import '../../data/models/healthcare/organization.dart';
import '../../data/repositories/healthcare_repository.dart';
import 'doctor_profile_screen.dart';
import 'healthcare_format.dart';
import 'widgets/healthcare_widgets.dart';

/// Everything the platform publishes about one healthcare provider:
/// contact details, branches and the doctors who can be booked there.
class OrganizationProfileScreen extends StatefulWidget {
  const OrganizationProfileScreen({super.key, required this.slug});

  final String slug;

  @override
  State<OrganizationProfileScreen> createState() =>
      _OrganizationProfileScreenState();
}

class _OrganizationProfileScreenState extends State<OrganizationProfileScreen> {
  final GlobalKey _doctorsKey = GlobalKey();

  ClinicLocation? _branch;

  void _chooseBranch(OrganizationDetail organization) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<ClinicLocation>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HcSectionHeader(title: l10n.hcChooseBranchTitle),
              Text(
                l10n.hcChooseBranchBody,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (final location in organization.locations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      minimumSize: const Size.fromHeight(60),
                    ),
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(location),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(location.name),
                        if (location.shortAddress.isNotEmpty)
                          Text(
                            location.shortAddress,
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _branch = selected);
    }
  }

  void _onBookNow(OrganizationDetail organization) {
    if (organization.locations.length > 1 && _branch == null) {
      _chooseBranch(organization);
      return;
    }
    if (organization.doctors.length == 1) {
      _openDoctor(organization.doctors.first, organization);
      return;
    }
    final contextForScroll = _doctorsKey.currentContext;
    if (contextForScroll != null) {
      Scrollable.ensureVisible(
        contextForScroll,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _openDoctor(DoctorSummary doctor, OrganizationDetail organization) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorProfileScreen(
          doctorId: doctor.id,
          organizationName: organization.name,
          branch: _branch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final repository = context.read<HealthcareRepository>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.hcFindTitle)),
      body: HcAsyncView<OrganizationDetail>(
        load: () => repository.organizationBySlug(widget.slug),
        builder: (context, organization, reload) {
          if (organization.locations.length == 1 && _branch == null) {
            // Only one branch: use it, so the booking records the right place.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _branch = organization.locations.first);
            });
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _Header(organization: organization),
              const SizedBox(height: 20),
              if (organization.doctors.isEmpty)
                HcEmptyView(
                  icon: Icons.person_off_rounded,
                  title: l10n.hcNoDoctorsTitle,
                  body: l10n.hcNoDoctorsBody,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _onBookNow(organization),
                    icon: const Icon(Icons.event_available_rounded),
                    label: Text(l10n.hcBookAppointment),
                  ),
                ),
              if (organization.tagline != null) ...[
                const SizedBox(height: 20),
                Text(
                  organization.tagline!,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
              if (organization.about != null) ...[
                const SizedBox(height: 20),
                HcSectionHeader(title: l10n.hcAbout),
                Text(organization.about!),
              ],
              const SizedBox(height: 24),
              HcSectionHeader(title: l10n.hcContact),
              _ContactCard(
                organization: organization,
                location: _branch,
                onCopyAddress: (text) async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.hcLocations)),
                  );
                },
              ),
              if (organization.locations.isNotEmpty) ...[
                const SizedBox(height: 24),
                HcSectionHeader(
                  title: l10n.hcLocations,
                  actionLabel: organization.locations.length > 1
                      ? l10n.hcChooseBranchTitle
                      : null,
                  onAction: organization.locations.length > 1
                      ? () => _chooseBranch(organization)
                      : null,
                ),
                for (final location in organization.locations)
                  _LocationRow(
                    location: location,
                    selected: _branch?.id == location.id,
                    onSelect: () => setState(() => _branch = location),
                  ),
              ],
              const SizedBox(height: 24),
              Container(
                key: _doctorsKey,
                child: HcSectionHeader(title: l10n.hcDoctorsTitle),
              ),
              if (_branch != null && organization.locations.length > 1)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: HcStatusChip(
                    label: '${l10n.hcBranch}: ${_branch!.name}',
                    tone: HcTone.positive,
                  ),
                ),
              if (organization.doctors.isEmpty)
                Text(
                  l10n.hcNoDoctorsBody,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                for (final doctor in organization.doctors)
                  HcDoctorCard(
                    doctor: doctor,
                    onTap: () => _openDoctor(doctor, organization),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.organization});

  final OrganizationDetail organization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cover = organization.coverImageUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cover != null && cover.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              cover,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        if (cover != null && cover.isNotEmpty) const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (organization.logoUrl != null &&
                organization.logoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  organization.logoUrl!,
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(width: 64, height: 64),
                ),
              ),
            if (organization.logoUrl != null &&
                organization.logoUrl!.isNotEmpty)
              const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    organization.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    HealthcareFormat.organizationTypeLabel(
                      organization.orgType,
                      l10n,
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (organization.isVerified)
              HcStatusChip(label: l10n.hcVerified, tone: HcTone.positive),
            HcStatusChip(
              label: l10n.hcDoctorCount(organization.doctors.length),
            ),
          ],
        ),
      ],
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.organization,
    required this.location,
    required this.onCopyAddress,
  });

  final OrganizationDetail organization;
  final ClinicLocation? location;
  final ValueChanged<String> onCopyAddress;

  Future<void> _launch(BuildContext context, Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).hcLoadFailedBody)),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).hcLoadFailedBody)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = location?.phone ?? organization.publicPhone;
    final website = organization.website;
    final email = organization.publicEmail;
    final address = location?.fullAddress;

    final rows = <Widget>[];
    void add(Widget row) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(row);
    }

    if (phone != null) {
      add(
        _ContactButton(
          icon: Icons.call_rounded,
          label: l10n.hcCall,
          value: phone,
          onTap: () => _launch(context, Uri(scheme: 'tel', path: phone)),
        ),
      );
    }
    if (email != null) {
      add(
        _ContactButton(
          icon: Icons.mail_rounded,
          label: l10n.hcEmail,
          value: email,
          onTap: () => _launch(context, Uri(scheme: 'mailto', path: email)),
        ),
      );
    }
    if (website != null) {
      final uri = Uri.tryParse(website);
      if (uri != null) {
        add(
          _ContactButton(
            icon: Icons.public_rounded,
            label: l10n.hcWebsite,
            value: website,
            onTap: () => _launch(context, uri),
          ),
        );
      }
    }
    if (address != null && address.isNotEmpty) {
      add(
        _ContactButton(
          icon: Icons.place_rounded,
          label: l10n.hcWhere,
          value: address,
          onTap: () => onCopyAddress(address),
        ),
      );
    }

    if (rows.isEmpty) {
      return Text(
        l10n.hcLoadFailedBody,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: rows),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 26, color: theme.colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(value, style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.location,
    required this.selected,
    required this.onSelect,
  });

  final ClinicLocation location;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = location.fullAddress;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onSelect,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                size: 26,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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
