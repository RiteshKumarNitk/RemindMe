import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/models/healthcare/appointment.dart';
import '../../../data/models/healthcare/doctor.dart';
import '../../../data/models/healthcare/organization.dart';
import '../healthcare_format.dart';

/// A section heading with an optional trailing action.
class HcSectionHeader extends StatelessWidget {
  const HcSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.xs),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

/// Grey placeholder rows shown while a list loads — no blocking spinner.
class HcSkeletonList extends StatelessWidget {
  const HcSkeletonList({super.key, this.rows = 4, this.rowHeight = 84});

  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            height: rowHeight,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              borderRadius: AppRadius.cardRadius,
            ),
          ),
      ],
    );
  }
}

/// Friendly failure state — never a raw exception.
class HcErrorView extends StatelessWidget {
  const HcErrorView({
    super.key,
    required this.title,
    required this.body,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  final String title;
  final String body;
  final VoidCallback? onRetry;
  final IconData icon;

  /// Builds a state from a platform error, keeping the backend's own
  /// message only where it is genuinely user-readable.
  factory HcErrorView.fromException(
    ApiException error,
    AppLocalizations l10n, {
    VoidCallback? onRetry,
  }) {
    if (error.isNetworkIssue) {
      return HcErrorView(
        title: l10n.hcOfflineTitle,
        body: l10n.hcLoadFailedBody,
        icon: Icons.wifi_off_rounded,
        onRetry: onRetry,
      );
    }
    if (error.code == 'NOT_FOUND') {
      return HcErrorView(
        title: l10n.hcUnavailableTitle,
        body: l10n.hcUnavailableBody,
        icon: Icons.location_off_rounded,
        onRetry: onRetry,
      );
    }
    return HcErrorView(
      title: l10n.hcLoadFailedTitle,
      body: l10n.hcLoadFailedBody,
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l10n.hcRetry),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Intentionally designed empty state.
class HcEmptyView extends StatelessWidget {
  const HcEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.5,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum HcTone { positive, pending, negative, neutral }

/// Status pill: colour **and** text, so status never relies on colour alone.
class HcStatusChip extends StatelessWidget {
  const HcStatusChip({super.key, required this.label, this.tone = HcTone.neutral});

  final String label;
  final HcTone tone;

  factory HcStatusChip.forAppointment(
    AppointmentStatus status,
    AppLocalizations l10n,
  ) {
    final tone = switch (status) {
      AppointmentStatus.confirmed ||
      AppointmentStatus.completed => HcTone.positive,
      AppointmentStatus.requested ||
      AppointmentStatus.checkedIn ||
      AppointmentStatus.waiting ||
      AppointmentStatus.inConsultation => HcTone.pending,
      AppointmentStatus.cancelled ||
      AppointmentStatus.noShow => HcTone.negative,
      _ => HcTone.neutral,
    };
    return HcStatusChip(
      label: HealthcareFormat.statusLabel(status, l10n),
      tone: tone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      HcTone.positive => (const Color(0xFFDCF2E1), const Color(0xFF14532D)),
      HcTone.pending => (const Color(0xFFFDF0D5), const Color(0xFF7A4A00)),
      HcTone.negative => (scheme.errorContainer, scheme.onErrorContainer),
      HcTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.chipRadius,
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A clinic/hospital row: logo, name, type, city, verification, doctor count.
class HcOrganizationCard extends StatelessWidget {
  const HcOrganizationCard({
    super.key,
    required this.organization,
    required this.onTap,
  });

  final OrganizationSummary organization;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final subtitle = [
      HealthcareFormat.organizationTypeLabel(organization.orgType, l10n),
      if (organization.cities.isNotEmpty) organization.cities.first,
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Logo(url: organization.logoUrl, fallbackIcon: Icons.local_hospital_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (organization.isVerified)
                          HcStatusChip(
                            label: l10n.hcVerified,
                            tone: HcTone.positive,
                          ),
                        HcStatusChip(
                          label: l10n.hcDoctorCount(organization.doctorCount),
                        ),
                      ],
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

/// A doctor row: photo, name, speciality, experience and published fee.
class HcDoctorCard extends StatelessWidget {
  const HcDoctorCard({
    super.key,
    required this.doctor,
    required this.onTap,
    this.showOrganization = false,
  });

  final DoctorSummary doctor;
  final VoidCallback onTap;
  final bool showOrganization;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fee = HealthcareFormat.fee(doctor.consultationFeeMinor);

    final details = <String>[
      if (doctor.specialty != null) doctor.specialty!,
      if (doctor.yearsOfExperience != null && doctor.yearsOfExperience! > 0)
        l10n.hcExperience(doctor.yearsOfExperience!),
      if (showOrganization && doctor.organizationName != null)
        doctor.organizationName!,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.cardRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              _Logo(url: doctor.photoUrl, fallbackIcon: Icons.person_rounded, circular: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doctor.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        details.join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (fee != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        l10n.hcConsultationFee(fee),
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
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

class _Logo extends StatelessWidget {
  const _Logo({
    required this.url,
    required this.fallbackIcon,
    this.circular = false,
  });

  final String? url;
  final IconData fallbackIcon;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(
      circular ? AppRadius.pill : AppRadius.sm,
    );
    final placeholder = Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: radius,
      ),
      child: Icon(fallbackIcon, color: theme.colorScheme.primary, size: 30),
    );

    if (url == null || url!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        // A broken image must not leave a hole: fall back to the icon.
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : placeholder,
      ),
    );
  }
}

/// Loads a future and renders skeleton → content → friendly error, with a
/// retry that simply re-runs the loader.
class HcAsyncView<T> extends StatefulWidget {
  const HcAsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.skeleton,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.xs,
      AppSpacing.lg,
      AppSpacing.xxl,
    ),
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;
  final Widget? skeleton;
  final EdgeInsetsGeometry padding;

  @override
  State<HcAsyncView<T>> createState() => _HcAsyncViewState<T>();
}

class _HcAsyncViewState<T> extends State<HcAsyncView<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  void _reload() {
    setState(() => _future = widget.load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: widget.padding,
            child: widget.skeleton ?? const HcSkeletonList(),
          );
        }
        final error = snapshot.error;
        if (error != null) {
          final l10n = AppLocalizations.of(context);
          return Padding(
            padding: widget.padding,
            child: error is ApiException
                ? HcErrorView.fromException(error, l10n, onRetry: _reload)
                : HcErrorView(
                    title: l10n.hcLoadFailedTitle,
                    body: l10n.hcLoadFailedBody,
                    onRetry: _reload,
                  ),
          );
        }
        final data = snapshot.data as T;
        return widget.builder(context, data, _reload);
      },
    );
  }
}
