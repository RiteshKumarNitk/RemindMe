import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_prompt.dart';
import '../../core/auth/auth_prompt.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/healthcare/consultation.dart';
import '../../data/models/healthcare/prescription.dart';
import '../../data/repositories/medical_record_repository.dart';
import '../../services/platform_auth_service.dart';
import 'healthcare_format.dart';
import 'widgets/healthcare_widgets.dart';
import '../login/login_screen.dart';

class MedicalRecordsScreen extends StatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  State<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends State<MedicalRecordsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = context.watch<PlatformAuthService>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.hcRecordsTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.hcConsultations),
              Tab(text: l10n.hcPrescriptions),
            ],
          ),
        ),
        body: !account.isSignedIn
            ? LoginScreen(
                onSkip: () {},
                onSignedIn: () {},
              )
            : const TabBarView(
                children: [
                  _ConsultationsTab(),
                  _PrescriptionsTab(),
                ],
              ),
      ),
    );
  }
}

class _ConsultationsTab extends StatefulWidget {
  const _ConsultationsTab();

  @override
  State<_ConsultationsTab> createState() => _ConsultationsTabState();
}

class _ConsultationsTabState extends State<_ConsultationsTab> {
  Future<List<Consultation>> _load() {
    return context.read<MedicalRecordRepository>().myConsultations();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return HcAsyncView<List<Consultation>>(
      load: _load,
      builder: (context, records, reload) {
        if (records.isEmpty) {
          return Center(
            child: Text(
              l10n.hcNoRecords,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final r = records[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.doctorName ?? 'Doctor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (r.signedAt != null)
                        Text(
                          HealthcareFormat.dayLong(r.signedAt!, 'UTC', Localizations.localeOf(context).languageCode),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      const Divider(height: 24),
                      if (r.subjective != null && r.subjective!.isNotEmpty) ...[
                        Text(l10n.hcNotes, style: Theme.of(context).textTheme.labelSmall),
                        Text(r.subjective!),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PrescriptionsTab extends StatefulWidget {
  const _PrescriptionsTab();

  @override
  State<_PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends State<_PrescriptionsTab> {
  Future<List<Prescription>> _load() {
    return context.read<MedicalRecordRepository>().myPrescriptions();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return HcAsyncView<List<Prescription>>(
      load: _load,
      builder: (context, records, reload) {
        if (records.isEmpty) {
          return Center(
            child: Text(
              l10n.hcNoRecords,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final r = records[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.doctorName ?? 'Doctor',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        HealthcareFormat.dayLong(r.issuedAt, 'UTC', Localizations.localeOf(context).languageCode),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 24),
                      Text(l10n.hcMedications, style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: AppSpacing.xs),
                      ...r.items.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text('• ${item.drugName} ${item.strength ?? ''} - ${item.frequency ?? ''}'),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
