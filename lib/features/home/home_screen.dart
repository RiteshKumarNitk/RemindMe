import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../services/auth_service.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../healthcare/widgets/home_care_section.dart';
import '../history/adherence_report_screen.dart';
import '../history/doctor_report_screen.dart';
import '../history/history_screen.dart';
import '../medicines/medicine_details_screen.dart';
import '../medicines/medicines_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_dialogs.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/app_states.dart';
import '../widgets/app_surfaces.dart';
import '../widgets/medicine_tiles.dart';
import '../widgets/reminder_card.dart';
import 'vitals_log_screen.dart';
import 'voice_mode_screen.dart';
import 'weekly_calendar_screen.dart';

/// The dashboard.
///
/// Answers one question — *which medicine do I need to take now?* — with a
/// single prominent card and one obvious button. Everything else on the screen
/// is deliberately quieter: the day's timeline, a one-line progress summary and
/// a short list of shortcuts.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onAddMedicine});

  final VoidCallback onAddMedicine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Time-of-day filter for the day's timeline. Defaults to the whole day so no
/// dose is ever hidden by a filter the user did not set.
enum _SlotFilter { all, morning, afternoon, evening }

_SlotFilter _slotFor(DateTime t) {
  if (t.hour < 12) return _SlotFilter.morning;
  if (t.hour < 17) return _SlotFilter.afternoon;
  return _SlotFilter.evening;
}

class _HomeScreenState extends State<HomeScreen> {
  _SlotFilter _slot = _SlotFilter.all;
  DoseStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final settings = context.watch<SettingsController>();
    final auth = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final locale = settings.settings.locale;
    final needsAttention =
        !appState.notificationsEnabled || !appState.exactAlarmsEnabled;

    final greeting = switch (now.hour) {
      < 12 => l10n.greetingMorning,
      < 17 => l10n.greetingAfternoon,
      _ => l10n.greetingEvening,
    };
    // Prefer the name typed during onboarding, then the Google account name.
    final name = settings.userName.trim().isNotEmpty
        ? settings.userName.trim()
        : auth.displayName.trim();

    final stats = appState.todayStats;
    final everythingDone =
        stats.total > 0 && stats.taken == stats.total && stats.missed == 0;
    final next = appState.nextDose;
    final scheduled = _filteredDoses(appState.todayDoses, settings);
    final pendingInView = scheduled
        .where(
          (e) =>
              e.effectiveStatus(settings.graceDuration, now) ==
              DoseStatus.pending,
        )
        .toList();

    final header = AppPageHeader(
      title: name.isEmpty ? greeting : '$greeting, $name',
      subtitle: AppDateUtils.dayLabel(now, locale),
      trailing: [
        if (needsAttention)
          AppIconButton(
            icon: Icons.notifications_active_rounded,
            semanticLabel: l10n.setPermissions,
            badge: true,
            onPressed: () {
              appState.requestAllPermissions();
              appState.requestExactAlarms();
            },
          ),
        _ProfileAvatar(
          name: name,
          photoUrl: auth.photoUrl,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          MediaQuery.paddingOf(context).bottom + 120,
        ),
        children: [
          header,
          const SizedBox(height: AppSpacing.lg),

          if (!appState.notificationsEnabled) ...[
            AppInfoNote(
              tone: AppNoteTone.warning,
              title: l10n.setNotifyPermission,
              message: l10n.setNotifDesc,
              actionLabel: l10n.permOk,
              actionIcon: Icons.settings_rounded,
              onAction: appState.requestAllPermissions,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (!appState.exactAlarmsEnabled) ...[
            AppInfoNote(
              tone: AppNoteTone.warning,
              title: l10n.setExactAlarm,
              message: l10n.setExactDesc,
              actionLabel: l10n.permOk,
              actionIcon: Icons.alarm_add_rounded,
              onAction: appState.requestExactAlarms,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          if (appState.loading)
            const SkeletonList(padding: EdgeInsets.zero, rows: 3)
          else if (appState.medicines.isEmpty)
            EmptyState(
              icon: Icons.medication_rounded,
              title: l10n.homeNoMedicines,
              message: l10n.homeEmptyBody,
              actionLabel: l10n.medAdd,
              onAction: widget.onAddMedicine,
            )
          else ...[
            // ── The one thing that matters ───────────────────────────────
            if (next != null)
              NextMedicineCard(
                entry: next,
                grace: settings.graceDuration,
                locale: locale,
                snoozeMinutes: settings.snoozeMinutes,
                onTake: () => _takeWithUndo(context, appState, next, l10n),
                onSnooze: () => _snooze(context, appState, next, l10n),
                onSkip: () => _confirmSkip(context, appState, next, l10n),
                onSpeak: () => _speak(context, next, l10n, settings),
              )
            else if (everythingDone)
              AppInfoNote(
                tone: AppNoteTone.success,
                icon: Icons.celebration_rounded,
                title: l10n.homeAllDoneToday,
                message: l10n.homeNoMoreToday,
              )
            else
              AppInfoNote(
                tone: AppNoteTone.success,
                icon: Icons.event_available_rounded,
                message: l10n.homeNoMoreToday,
              ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Today's medicines ────────────────────────────────────────
            AppSectionHeader(
              title: l10n.homeTodayMedicines,
              trailing: _StatusFilter(
                value: _statusFilter,
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (appState.todayDoses.isNotEmpty) ...[
              _SlotChips(
                selected: _slot,
                onSelected: (s) => setState(() => _slot = s),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (appState.todayDoses.isEmpty)
              AppInfoNote(
                tone: AppNoteTone.neutral,
                message: l10n.homeEmptySchedule,
              )
            else if (scheduled.isEmpty)
              AppInfoNote(
                tone: AppNoteTone.neutral,
                message: l10n.homeEmptySchedule,
              )
            else
              for (var i = 0; i < scheduled.length; i++)
                MedicineDoseTile(
                  entry: scheduled[i],
                  locale: locale,
                  grace: settings.graceDuration,
                  isNext: next?.dose.id == scheduled[i].dose.id,
                  railTop: i != 0,
                  railBottom: i != scheduled.length - 1,
                  onTake: () =>
                      _takeWithUndo(context, appState, scheduled[i], l10n),
                  onSkip: () =>
                      _confirmSkip(context, appState, scheduled[i], l10n),
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => MedicineDetailsScreen(
                        medicine: scheduled[i].medicine,
                      ),
                    ),
                  ),
                ),

            if (pendingInView.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              AppButton.secondary(
                label: l10n.homeBatchMarkAll,
                icon: Icons.done_all_rounded,
                onPressed: () => _batchMarkAll(context, appState, pendingInView),
              ),
            ],

            const SizedBox(height: AppSpacing.xxl),

            // ── Progress ─────────────────────────────────────────────────
            AppSectionHeader(title: l10n.homeDailyProgress),
            const SizedBox(height: AppSpacing.sm),
            ProgressCard(stats: stats),

            const SizedBox(height: AppSpacing.xxl),

            // ── Healthcare discovery ─────────────────────────────────────
            // An extra capability below the medicine dashboard: find a clinic
            // or hospital from the platform, and see the next real appointment.
            // A failed clinic lookup stays silent — reminders come first.
            const HomeCareSection(),

            const SizedBox(height: AppSpacing.xxl),

            // ── Shortcuts ────────────────────────────────────────────────
            AppSectionHeader(title: l10n.homeQuickActions),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.medAdd,
              icon: Icons.add_rounded,
              onPressed: widget.onAddMedicine,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: l10n.histTitle,
                    icon: Icons.history_rounded,
                    onPressed: () => _pushTab(
                      context,
                      title: l10n.histTitle,
                      child: const HistoryScreen(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: AppButton.secondary(
                    label: l10n.medTitle,
                    icon: Icons.medication_rounded,
                    onPressed: () => _pushTab(
                      context,
                      title: l10n.medTitle,
                      child: const MedicinesScreen(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
            AppSectionHeader(title: l10n.homeMoreTools),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppListRow(
                    title: l10n.qaWeeklyCalendar,
                    leading: AppIconBubble(
                      icon: Icons.calendar_month_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    onTap: () => _push(context, const WeeklyCalendarScreen()),
                  ),
                  const AppDivider(indent: AppSpacing.md),
                  AppListRow(
                    title: l10n.qaAdherenceReport,
                    leading: AppIconBubble(
                      icon: Icons.insights_rounded,
                      color: theme.palette.success,
                    ),
                    onTap: () => _push(context, const AdherenceReportScreen()),
                  ),
                  const AppDivider(indent: AppSpacing.md),
                  AppListRow(
                    title: l10n.qaDoctorReport,
                    leading: AppIconBubble(
                      icon: Icons.local_hospital_rounded,
                      color: theme.colorScheme.tertiary,
                    ),
                    onTap: () => _push(context, const DoctorReportScreen()),
                  ),
                  const AppDivider(indent: AppSpacing.md),
                  AppListRow(
                    title: l10n.qaVoiceMode,
                    leading: AppIconBubble(
                      icon: Icons.record_voice_over_rounded,
                      color: theme.accentColor,
                    ),
                    onTap: () => _push(context, const VoiceModeScreen()),
                  ),
                  const AppDivider(indent: AppSpacing.md),
                  AppListRow(
                    title: l10n.qaVitalsLog,
                    leading: AppIconBubble(
                      icon: Icons.favorite_rounded,
                      color: theme.missedColor,
                    ),
                    onTap: () => _push(context, const VitalsLogScreen()),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  /// Pushes a tab screen (which has no Scaffold of its own) as a standalone
  /// page with a title bar and a back button.
  void _pushTab(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(appBar: AppBar(title: Text(title)), body: child),
      ),
    );
  }

  List<DoseEntry> _filteredDoses(
    List<DoseEntry> doses,
    SettingsController settings,
  ) {
    final now = DateTime.now();
    return doses.where((e) {
      if (_slot != _SlotFilter.all && _slotFor(e.dose.scheduledAt) != _slot) {
        return false;
      }
      if (_statusFilter != null) {
        return e.effectiveStatus(settings.graceDuration, now) == _statusFilter;
      }
      return true;
    }).toList()..sort((a, b) => a.dose.scheduledAt.compareTo(b.dose.scheduledAt));
  }

  Future<void> _takeWithUndo(
    BuildContext context,
    AppState appState,
    DoseEntry entry,
    AppLocalizations l10n,
  ) async {
    await appState.markTaken(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.undoTaken),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => appState.undoLastAction(),
          ),
        ),
      );
  }

  Future<void> _snooze(
    BuildContext context,
    AppState appState,
    DoseEntry entry,
    AppLocalizations l10n,
  ) async {
    await appState.markSnoozed(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.homeSnoozedUntil(
              AppDateUtils.timeLabel(
                DateTime.now().add(appState.settings.snoozeDuration),
                appState.settings.settings.locale,
              ),
            ),
          ),
        ),
      );
  }

  Future<void> _confirmSkip(
    BuildContext context,
    AppState appState,
    DoseEntry entry,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.homeSkipConfirmTitle,
      message: l10n.homeSkipConfirmBody(entry.medicine.name),
      confirmLabel: l10n.homeSkip,
      cancelLabel: l10n.btnCancel,
      destructive: false,
      icon: Icons.close_rounded,
    );
    if (!confirmed) return;
    await appState.markSkipped(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.undoSkipped),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => appState.undoLastAction(),
          ),
        ),
      );
  }

  Future<void> _batchMarkAll(
    BuildContext context,
    AppState appState,
    List<DoseEntry> pending,
  ) async {
    for (final entry in pending) {
      await appState.markTaken(entry);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).homeBatchMarkAll),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: AppLocalizations.of(context).undo,
          onPressed: () => appState.undoLastAction(),
        ),
      ),
    );
  }

  void _speak(
    BuildContext context,
    DoseEntry entry,
    AppLocalizations l10n,
    SettingsController settings,
  ) {
    context.read<AppState>().voice.speak(
      l10n.voiceTimeToTake(entry.medicine.name, entry.medicine.doseLabel),
      settings.settings.locale,
    );
  }
}

// ---------------------------------------------------------------------------
// Header pieces
// ---------------------------------------------------------------------------

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.name,
    required this.photoUrl,
    required this.onTap,
  });

  final String name;
  final String photoUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = name.isEmpty
        ? null
        : name.trim().characters.first.toUpperCase();
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).navProfile,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: AppSizes.tapTarget,
          height: AppSizes.tapTarget,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainer,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: photoUrl.isEmpty
              ? (label == null
                    ? Icon(
                        Icons.person_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      )
                    : Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ))
              : ClipOval(
                  child: Image.network(
                    photoUrl,
                    width: AppSizes.tapTarget,
                    height: AppSizes.tapTarget,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day filters
// ---------------------------------------------------------------------------

class _SlotChips extends StatelessWidget {
  const _SlotChips({required this.selected, required this.onSelected});

  final _SlotFilter selected;
  final ValueChanged<_SlotFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      _SlotFilter.all: l10n.histAll,
      _SlotFilter.morning: l10n.medTimeSlotMorning,
      _SlotFilter.afternoon: l10n.medTimeSlotAfternoon,
      _SlotFilter.evening: l10n.medTimeSlotEvening,
    };
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final slot in _SlotFilter.values)
          ChoiceChip(
            label: Text(labels[slot]!),
            selected: slot == selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(slot),
          ),
      ],
    );
  }
}

class _StatusFilter extends StatelessWidget {
  const _StatusFilter({required this.value, required this.onChanged});

  final DoseStatus? value;
  final ValueChanged<DoseStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final label = switch (value) {
      DoseStatus.taken => l10n.statusTaken,
      DoseStatus.pending => l10n.statusPending,
      DoseStatus.missed => l10n.statusMissed,
      DoseStatus.skipped => l10n.statusSkipped,
      null => l10n.histAll,
    };
    return PopupMenuButton<DoseStatus?>(
      initialValue: value,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      tooltip: label,
      itemBuilder: (context) => [
        PopupMenuItem(value: null, child: Text(l10n.histAll)),
        PopupMenuItem(
          value: DoseStatus.pending,
          child: Text(l10n.statusPending),
        ),
        PopupMenuItem(value: DoseStatus.taken, child: Text(l10n.statusTaken)),
        PopupMenuItem(value: DoseStatus.missed, child: Text(l10n.statusMissed)),
        PopupMenuItem(
          value: DoseStatus.skipped,
          child: Text(l10n.statusSkipped),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.chipRadius,
          border: Border.all(color: theme.cardBorder, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_rounded,
              size: AppSizes.iconSm,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

