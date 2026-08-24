import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../services/sync/sync_service.dart';
import '../../state/app_state.dart';
import '../widgets/adherence_card.dart';
import '../widgets/big_button.dart';
import '../widgets/dose_list_tile.dart';

/// Read-only caregiver dashboard: weekly adherence + today's dose list for
/// the household. Refreshes from the cloud (Firestore) by pulling a fresh
/// sync into the offline-first local DB before reading.
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
    // build. A completed sync refreshes AppState (revision bump), which
    // triggers the reload below.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<SyncService>().syncNow());
    });
  }

  /// Computes the stats from the local mirror of the household data (kept in
  /// sync by [SyncService]). Degrades gracefully when offline: the last
  /// synced local copy is still shown.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final appState = context.watch<AppState>();
    if (_lastRevision != appState.revision) {
      _lastRevision = appState.revision;
      _future = _load();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.caregiverTitle)),
      body: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data;
          if (data == null) {
            return const SizedBox.shrink();
          }
          final grace = appState.settings.graceDuration;
          final locale = appState.settings.settings.locale;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              BigButton(
                label: l10n.caregiverRefresh,
                icon: Icons.refresh_rounded,
                outlined: true,
                height: 56,
                onPressed: () {
                  unawaited(context.read<SyncService>().syncNow());
                  setState(() => _future = _load());
                },
              ),
              const SizedBox(height: 16),
              Text(
                l10n.caregiverThisWeek,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              AdherenceCard(stats: data.weekStats, l10n: l10n),
              const SizedBox(height: 20),
              Text(
                l10n.histToday,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              if (data.todayEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      l10n.homeEmptySchedule,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                )
              else
                for (final e in data.todayEntries)
                  DoseListTile(entry: e, grace: grace, locale: locale),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardData {
  final AdherenceStats weekStats;
  final List<DoseEntry> todayEntries;
  const _DashboardData({required this.weekStats, required this.todayEntries});
}
