import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../services/sync/sync_service.dart';
import '../../state/app_state.dart';
import '../widgets/adherence_card.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/dose_list_tile.dart';

/// Read-only caregiver dashboard: weekly adherence + today's doses for the
/// household. Refreshes from the cloud (Firestore) by pulling a fresh sync
/// into the offline-first local DB before reading, so it still shows the last
/// synced copy when the phone is offline.
class CaregiverDashboardScreen extends StatefulWidget {
  const CaregiverDashboardScreen({super.key});

  @override
  State<CaregiverDashboardScreen> createState() =>
      _CaregiverDashboardScreenState();
}

class _CaregiverDashboardScreenState extends State<CaregiverDashboardScreen> {
  int? _lastRevision;
  Future<_DashboardData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // Pull fresh household data from the cloud in the background, after the
    // first frame: syncNow() notifies providers, which must not happen during
    // build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<SyncService>().syncNow());
    });
  }

  Future<_DashboardData> _load() async {
    final appState = context.read<AppState>();
    final now = DateTime.now();

    final weekStart = AppDateUtils.startOfWeek(now);
    final (_, weekStats) = await appState.historyFor(
      weekStart,
      weekStart.add(const Duration(days: 7)),
    );

    final todayStart = AppDateUtils.startOfDay(now);
    final (todayEntries, _) = await appState.historyFor(
      todayStart,
      todayStart.add(const Duration(days: 1)),
    );
    return _DashboardData(weekStats: weekStats, todayEntries: todayEntries);
  }

  void _refresh() {
    unawaited(context.read<SyncService>().syncNow());
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final appState = context.watch<AppState>();
    if (_lastRevision != appState.revision) {
      _lastRevision = appState.revision;
      _future = _load();
    }

    return AppPage(
      title: l10n.caregiverTitle,
      subtitle: l10n.caregiverDesc,
      actions: [
        IconButton(
          onPressed: _refresh,
          tooltip: l10n.caregiverRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      children: [
        FutureBuilder<_DashboardData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SkeletonList(padding: EdgeInsets.zero, rows: 3);
            }
            final data = snapshot.data;
            if (data == null) {
              return ErrorState(
                title: l10n.errorTitle,
                message: l10n.errorBody,
                retryLabel: l10n.errorRetry,
                onRetry: _refresh,
              );
            }
            final grace = appState.settings.graceDuration;
            final locale = appState.settings.settings.locale;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(title: l10n.caregiverThisWeek),
                const SizedBox(height: AppSpacing.sm),
                AdherenceCard(stats: data.weekStats, l10n: l10n),

                const SizedBox(height: AppSpacing.xl),
                AppSectionHeader(title: l10n.histToday),
                const SizedBox(height: AppSpacing.sm),
                if (data.todayEntries.isEmpty)
                  AppInfoNote(
                    tone: AppNoteTone.neutral,
                    message: l10n.homeEmptySchedule,
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < data.todayEntries.length; i++) ...[
                          DoseListTile(
                            entry: data.todayEntries[i],
                            grace: grace,
                            locale: locale,
                          ),
                          if (i != data.todayEntries.length - 1)
                            const AppDivider(indent: AppSpacing.md),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.xl),
                AppButton.secondary(
                  label: l10n.caregiverRefresh,
                  icon: Icons.refresh_rounded,
                  onPressed: _refresh,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DashboardData {
  const _DashboardData({required this.weekStats, required this.todayEntries});

  final AdherenceStats weekStats;
  final List<DoseEntry> todayEntries;
}
