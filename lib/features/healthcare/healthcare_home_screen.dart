import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/platform_api_config.dart';
import '../../core/localization/generated/app_localizations.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/healthcare/organization.dart';
import '../../data/repositories/healthcare_repository.dart';
import '../../services/platform_auth_service.dart';
import 'appointments_screen.dart';
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

  final List<OrganizationSummary> _results = [];
  int _page = 0;
  int _total = 0;
  bool _loading = false;
  ApiException? _error;

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

  bool get _hasMore => _results.length < _total;

  Future<void> _load({bool reset = false}) async {
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
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(''),
                    child: Text(l10n.hcClear),
                  ),
                ),
                const SizedBox(width: 12),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
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
            Row(
              children: [
                Expanded(
                  child: HcSectionHeader(
                    title: _city == null
                        ? l10n.hcProvidersTitle
                        : '${l10n.hcProvidersTitle} · $_city',
                  ),
                ),
                TextButton.icon(
                  onPressed: _openFilters,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  label: Text(l10n.hcFiltersTitle),
                ),
              ],
            ),
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
          ],
        ),
      ),
    );
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
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
