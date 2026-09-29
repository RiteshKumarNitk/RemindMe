import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/platform_api_config.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/healthcare/organization.dart';
import '../../data/models/healthcare/doctor.dart';
import '../../data/repositories/healthcare_repository.dart';
import '../../services/platform_auth_service.dart';
import 'appointments_screen.dart';
import 'doctor_profile_screen.dart';
import 'organization_profile_screen.dart';
import 'platform_sign_in_screen.dart';
import 'widgets/healthcare_widgets.dart';

/// Find healthcare: every clinic, hospital or diagnostic centre that the
/// platform has published.
///
/// The list is the platform's own `/api/public/organizations` result — the
/// screen never filters by its own idea of what should be visible, and never
/// shows anything the API did not return.
class HealthcareHomeScreen extends StatefulWidget {
  const HealthcareHomeScreen({super.key});

  @override
  State<HealthcareHomeScreen> createState() => _HealthcareHomeScreenState();
}

class _HealthcareHomeScreenState extends State<HealthcareHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Organization types are the ones the backend defines; the chips only
  /// pass the raw value through as a filter.
  static const List<String?> _typeFilters = [
    null,
    OrganizationType.hospital,
    OrganizationType.clinic,
    OrganizationType.polyclinic,
    OrganizationType.diagnosticCenter,
    OrganizationType.other,
  ];

  String? _type;
  String? _city;
  String? _query;

  /// Result tab: clinics (organizations) or doctors. One search box feeds
  /// both — the backend applies the term to whichever surface is shown.
  _HcTab _tab = _HcTab.clinics;

  final List<OrganizationSummary> _results = [];
  final List<DoctorSummary> _doctorResults = [];
  int _page = 0;
  int _doctorPage = 0;
  int _total = 0;
  int _doctorTotal = 0;
  bool _loading = false;
  bool _doctorLoading = false;
  ApiException? _error;
  ApiException? _doctorError;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasMore => _tab == _HcTab.clinics
      ? _results.length < _total
      : _doctorResults.length < _doctorTotal;

  Future<void> _load({bool reset = false}) async {
    if (_tab == _HcTab.doctors) {
      await _loadDoctors(reset: reset);
      return;
    }
    await _loadOrganizations(reset: reset);
  }

  Future<void> _loadOrganizations({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _page = 0;
        _results.clear();
        _total = 0;
      }
    });

    final repository = context.read<HealthcareRepository>();
    try {
      final page = await repository.searchOrganizations(
        query: _query,
        city: _city,
        orgType: _type,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _page = page.page;
        _total = page.total;
        _results.addAll(page.items);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _loadDoctors({bool reset = false}) async {
    if (_doctorLoading) return;
    setState(() {
      _doctorLoading = true;
      _doctorError = null;
      if (reset) {
        _doctorPage = 0;
        _doctorResults.clear();
        _doctorTotal = 0;
      }
    });

    final repository = context.read<HealthcareRepository>();
    try {
      final page = await repository.searchDoctors(
        query: _query,
        page: _doctorPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _doctorPage = page.page;
        _doctorTotal = page.total;
        _doctorResults.addAll(page.items);
        _doctorLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _doctorError = e;
        _doctorLoading = false;
      });
    }
  }

  void _switchTab(_HcTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
    final alreadyLoaded = tab == _HcTab.clinics ? _results.isNotEmpty : _doctorResults.isNotEmpty;
    if (!alreadyLoaded) _load(reset: true);
  }

  void _submitSearch(String value) {
    final trimmed = value.trim();
    setState(() => _query = trimmed.isEmpty ? null : trimmed);
    _load(reset: true);
  }

  Future<void> _openFilters() async {
    final controller = TextEditingController(text: _city ?? '');
    final l10n = AppLocalizations.of(context);
    final applied = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.xs,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HcSectionHeader(title: l10n.hcFiltersTitle),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.hcCityLabel,
                hintText: l10n.hcCityHint,
                prefixIcon: const Icon(Icons.location_city_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(''),
                    child: Text(l10n.hcClear),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(sheetContext).pop(controller.text.trim()),
                    child: Text(l10n.hcApply),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (applied == null) return; // sheet dismissed
    setState(() => _city = applied.isEmpty ? null : applied);
    _load(reset: true);
  }

  void _openOrganization(OrganizationSummary organization) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            OrganizationProfileScreen(slug: organization.slug),
      ),
    );
  }

  void _openDoctor(DoctorSummary doctor) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DoctorProfileScreen(doctorId: doctor.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = context.watch<PlatformAuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hcFindTitle),
        actions: [
          IconButton(
            tooltip: l10n.hcViewAllAppointments,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AppointmentsScreen(),
              ),
            ),
            icon: const Icon(Icons.event_note_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.hcCareSection,
            onSelected: (value) async {
              switch (value) {
                case 'signin':
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlatformSignInScreen(),
                    ),
                  );
                case 'signout':
                  await context.read<PlatformAuthService>().signOut();
                case 'server':
                  if (mounted) await _openServerSettings();
              }
            },
            itemBuilder: (context) => [
              if (account.isSignedIn)
                PopupMenuItem(
                  value: 'signout',
                  child: Text(l10n.hcSignOut),
                )
              else
                PopupMenuItem(
                  value: 'signin',
                  child: Text(l10n.hcSignIn),
                ),
              if (PlatformApiConfig.overrideAllowed)
                PopupMenuItem(
                  value: 'server',
                  child: Text(l10n.hcApiSettingsTitle),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            if (account.isSignedIn)
              _SignedInBanner(
                name: account.user?.fullName ?? account.user?.email ?? '',
                l10n: l10n,
              ),
            _SearchField(
              controller: _searchController,
              hint: l10n.hcSearchHint,
              actionLabel: l10n.hcSearchAction,
              onSubmitted: _submitSearch,
              onClear: () {
                _searchController.clear();
                _submitSearch('');
              },
            ),
            const SizedBox(height: 12),
            // Result-type tabs (request §32/§33): the same search box serves
            // clinics and doctors; the backend filters whichever is shown.
            SegmentedButton<_HcTab>(
              segments: [
                ButtonSegment(
                  value: _HcTab.clinics,
                  icon: const Icon(Icons.local_hospital_rounded, size: 18),
                  label: Text(l10n.hcTabClinics),
                ),
                ButtonSegment(
                  value: _HcTab.doctors,
                  icon: const Icon(Icons.person_rounded, size: 18),
                  label: Text(l10n.hcTabDoctors),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (selection) => _switchTab(selection.first),
            ),
            const SizedBox(height: 8),
            if (_tab == _HcTab.clinics) ...[
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _typeFilters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final value = _typeFilters[index];
                    return ChoiceChip(
                      label: Text(_typeLabel(value, l10n)),
                      selected: _type == value,
                      onSelected: (_) {
                        setState(() => _type = value);
                        _load(reset: true);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: HcSectionHeader(
                    title: _tab == _HcTab.clinics
                        ? (_city == null
                              ? l10n.hcProvidersTitle
                              : '${l10n.hcProvidersTitle} · $_city')
                        : l10n.hcDoctorsTitle,
                  ),
                ),
                if (_tab == _HcTab.clinics)
                  TextButton.icon(
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune_rounded, size: 20),
                    label: Text(l10n.hcFiltersTitle),
                  ),
              ],
            ),
            if (_tab == _HcTab.clinics)
              ..._buildClinicResults(l10n)
            else
              ..._buildDoctorResults(l10n),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildClinicResults(AppLocalizations l10n) {
    return [
      if (_error != null)
        HcErrorView.fromException(
          _error!,
          l10n,
          onRetry: () => _load(reset: true),
        )
      else if (_loading && _results.isEmpty)
        const HcSkeletonList()
      else if (_results.isEmpty)
        HcEmptyView(
          icon: Icons.search_off_rounded,
          title: l10n.hcSearchEmptyTitle,
          body: l10n.hcSearchEmptyBody,
          actionLabel: (_query != null || _city != null || _type != null)
              ? l10n.hcClear
              : null,
          onAction: () {
            _searchController.clear();
            setState(() {
              _query = null;
              _city = null;
              _type = null;
            });
            _load(reset: true);
          },
        )
      else ...[
        for (final organization in _results)
          HcOrganizationCard(
            organization: organization,
            onTap: () => _openOrganization(organization),
          ),
        if (_hasMore)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _loading ? null : () => _load(),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.hcLoadMore),
            ),
          ),
      ],
    ];
  }

  List<Widget> _buildDoctorResults(AppLocalizations l10n) {
    return [
      if (_doctorError != null)
        HcErrorView.fromException(
          _doctorError!,
          l10n,
          onRetry: () => _load(reset: true),
        )
      else if (_doctorLoading && _doctorResults.isEmpty)
        const HcSkeletonList()
      else if (_doctorResults.isEmpty)
        HcEmptyView(
          icon: Icons.person_search_rounded,
          title: l10n.hcNoDoctorsFoundTitle,
          body: l10n.hcNoDoctorsFoundBody,
          actionLabel: _query != null ? l10n.hcClear : null,
          onAction: () {
            _searchController.clear();
            setState(() => _query = null);
            _load(reset: true);
          },
        )
      else ...[
        for (final doctor in _doctorResults)
          HcDoctorCard(
            doctor: doctor,
            showOrganization: true,
            onTap: () => _openDoctor(doctor),
          ),
        if (_hasMore)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _doctorLoading ? null : () => _load(),
              child: _doctorLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.hcLoadMore),
            ),
          ),
      ],
    ];
  }

  String _typeLabel(String? value, AppLocalizations l10n) {
    switch (value) {
      case OrganizationType.hospital:
        return l10n.hcTypeHospital;
      case OrganizationType.clinic:
        return l10n.hcTypeClinic;
      case OrganizationType.polyclinic:
        return l10n.hcTypePolyclinic;
      case OrganizationType.diagnosticCenter:
        return l10n.hcTypeDiagnostic;
      case OrganizationType.other:
        return l10n.hcTypeOther;
      default:
        return l10n.hcAllTypes;
    }
  }

  /// QA-only: point the app at a different clinic server without rebuilding.
  Future<void> _openServerSettings() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(
      text: PlatformApiConfig.hasOverride
          ? PlatformApiConfig.baseUrl
          : PlatformApiConfig.compiledBaseUrl,
    );
    final saved = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.hcApiSettingsTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.hcApiSettingsHint),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: 'https://host/api'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.btnCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(''),
            child: Text(l10n.hcApiSettingsReset),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.btnSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == null || !mounted) return;

    final repository = context.read<HealthcareRepository>();
    final account = context.read<PlatformAuthService>();
    await PlatformApiConfig.setOverride(saved);
    repository.clearCaches();
    await account.restore();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.hcApiSettingsSaved)));
    _load(reset: true);
  }
}

enum _HcTab { clinics, doctors }

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.actionLabel,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final String actionLabel;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      textCapitalization: TextCapitalization.words,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: actionLabel,
          onPressed: onClear,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _SignedInBanner extends StatelessWidget {
  const _SignedInBanner({required this.name, required this.l10n});

  final String name;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: AppSizes.iconMd,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.hcSignedInAs(name),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
