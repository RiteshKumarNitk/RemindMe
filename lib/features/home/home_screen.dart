import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utilities/date_utils.dart';
import '../../data/models/adherence_stats.dart';
import '../../data/models/dose_entry.dart';
import '../../data/models/dose_status.dart';
import '../../data/models/food_instruction.dart';
import '../../services/auth_service.dart';
import '../../services/settings_controller.dart';
import '../../state/app_state.dart';
import '../settings/settings_screen.dart';
import '../widgets/big_button.dart';
import '../widgets/permission_banner.dart';
import 'weekly_calendar_screen.dart';
import 'voice_mode_screen.dart';
import 'vitals_log_screen.dart';
import '../history/adherence_report_screen.dart';
import '../history/doctor_report_screen.dart';

/// The dashboard. Answers "which medicine do I need to take now?" at a glance,
/// styled to the product design mockups (indigo hero card, coral accents,
/// time-of-day schedule filter and a daily-progress summary).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onAddMedicine});

  final VoidCallback onAddMedicine;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _TimeSlot { morning, afternoon, evening }

_TimeSlot _slotFor(DateTime t) {
  if (t.hour < 12) return _TimeSlot.morning;
  if (t.hour < 17) return _TimeSlot.afternoon;
  return _TimeSlot.evening;
}

class _HomeScreenState extends State<HomeScreen> {
  // Time-of-day filter for "Today's Schedule". Defaults to the current period.
  _TimeSlot _slot = _slotFor(DateTime.now());

  // Status filter behind the "All" dropdown.
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

    final greeting = switch (now.hour) {
      < 12 => l10n.greetingMorning,
      < 17 => l10n.greetingAfternoon,
      _ => l10n.greetingEvening,
    };
    // Prefer the name the user typed in onboarding; fall back to their
    // Google account name; then the first part of their email.
    final name = settings.userName.trim().isNotEmpty
        ? settings.userName.trim()
        : auth.displayName.trim().isNotEmpty
        ? auth.displayName.trim()
        : (auth.email.contains('@') ? auth.email.split('@').first : '');

    final stats = appState.todayStats;
    final allDone = stats.taken > 0 && stats.missed == 0 && stats.pending == 0;

    final scheduled = _filteredDoses(appState.todayDoses, settings, now);
    final hasPendingInView = scheduled.any(
      (e) => e.effectiveStatus(settings.graceDuration, now) == DoseStatus.pending,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          // Clear the floating pill nav bar + FAB at the bottom.
          MediaQuery.paddingOf(context).bottom + 108,
        ),
        children: [
          _Header(
            name: name,
            photoUrl: auth.photoUrl,
            alert: !appState.notificationsEnabled || !appState.exactAlarmsEnabled,
            onProfile: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
            onBell: () {
              if (!appState.notificationsEnabled ||
                  !appState.exactAlarmsEnabled) {
                appState.requestAllPermissions();
                appState.requestExactAlarms();
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 20),
          Text(
            name.isEmpty ? greeting : '$greeting, $name',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homeWellnessSubtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          if (allDone) ...[
            const SizedBox(height: 16),
            _StreakBanner(text: l10n.homeAllDoneToday),
          ],

          const SizedBox(height: 12),
          PermissionBanner(
            show: !appState.notificationsEnabled,
            title: l10n.setNotifyPermission,
            subtitle: l10n.setNotifDesc,
            buttonLabel: l10n.permOk,
            onPressed: () => appState.requestAllPermissions(),
          ),
          if (!appState.notificationsEnabled) const SizedBox(height: 10),
          PermissionBanner(
            show: !appState.exactAlarmsEnabled,
            title: l10n.setExactAlarm,
            subtitle: l10n.setExactDesc,
            buttonLabel: l10n.permOk,
            icon: Icons.alarm_add_rounded,
            onPressed: () => appState.requestExactAlarms(),
          ),

          if (appState.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            const SizedBox(height: 24),
            _SectionLabel(l10n.homeUpcomingDose),
            const SizedBox(height: 10),
            if (appState.nextDose != null)
              _UpcomingDoseCard(entry: appState.nextDose!)
            else
              _AllDoneCard(text: l10n.homeNoMoreToday),

            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _SectionLabel(l10n.homeScheduleTitle)),
                _StatusDropdown(
                  value: _statusFilter,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SlotChips(
              selected: _slot,
              onSelected: (s) => setState(() => _slot = s),
            ),
            const SizedBox(height: 14),

            if (appState.todayDoses.isEmpty)
              _EmptyToday(
                l10n: l10n,
                hasMedicines: appState.medicines.isNotEmpty,
                onAddMedicine: widget.onAddMedicine,
              )
            else if (scheduled.isEmpty)
              _EmptySlot(text: l10n.homeEmptySchedule)
            else ...[
              for (final entry in scheduled)
                _ScheduleTile(
                  entry: entry,
                  locale: locale,
                  grace: settings.graceDuration,
                  isNext: appState.nextDose?.dose.id == entry.dose.id,
                  onLog: () => _markTakenWithUndo(context, appState, entry, l10n),
                ),
              if (hasPendingInView) ...[
                const SizedBox(height: 4),
                BigTextButton(
                  label: l10n.homeBatchMarkAll,
                  onPressed: () =>
                      _batchMarkAll(context, appState, scheduled, l10n),
                ),
              ],
            ],

            const SizedBox(height: 24),
            _SectionLabel(l10n.homeDailyProgress),
            const SizedBox(height: 12),
            _ProgressSummary(stats: stats, l10n: l10n),

            const SizedBox(height: 24),
            Text(
              'Quick Actions',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _QuickActions(
              onCalendar: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WeeklyCalendarScreen(),
                ),
              ),
              onReport: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdherenceReportScreen(),
                ),
              ),
              onDoctorReport: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DoctorReportScreen(),
                ),
              ),
              onVoiceMode: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VoiceModeScreen(),
                ),
              ),
              onVitals: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const VitalsLogScreen(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<DoseEntry> _filteredDoses(
    List<DoseEntry> doses,
    SettingsController settings,
    DateTime now,
  ) {
    return doses.where((e) {
      if (_slotFor(e.dose.scheduledAt) != _slot) return false;
      if (_statusFilter != null) {
        return e.effectiveStatus(settings.graceDuration, now) == _statusFilter;
      }
      return true;
    }).toList()..sort((a, b) => a.dose.scheduledAt.compareTo(b.dose.scheduledAt));
  }

  Future<void> _markTakenWithUndo(
    BuildContext context,
    AppState appState,
    DoseEntry entry,
    AppLocalizations l10n,
  ) async {
    await appState.markTaken(entry);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
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

  Future<void> _batchMarkAll(
    BuildContext context,
    AppState appState,
    List<DoseEntry> inView,
    AppLocalizations l10n,
  ) async {
    final grace = appState.settings.graceDuration;
    final pending = inView
        .where(
          (e) => e.effectiveStatus(grace, DateTime.now()) == DoseStatus.pending,
        )
        .toList();
    for (final entry in pending) {
      await appState.markTaken(entry);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.homeBatchMarkAll)));
    }
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.photoUrl,
    required this.alert,
    required this.onBell,
    required this.onProfile,
  });

  final String name;
  final String photoUrl;
  final bool alert;
  final VoidCallback onBell;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatar = CircleAvatar(
      radius: 22,
      backgroundColor: theme.colorScheme.primaryContainer,
      foregroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
      child: name.isNotEmpty
          ? Text(
              name.characters.first.toUpperCase(),
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(
              Icons.person_rounded,
              color: theme.colorScheme.onPrimaryContainer,
            ),
    );
    return Row(
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onProfile,
          child: avatar,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onProfile,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DoseWise',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  name.isEmpty ? 'DoseWise' : name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onBell,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            if (alert)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.successColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Upcoming dose hero card
// ---------------------------------------------------------------------------

String _foodLabel(AppLocalizations l10n, FoodInstruction f) => switch (f) {
  FoodInstruction.before => l10n.foodBefore,
  FoodInstruction.after => l10n.foodAfter,
  FoodInstruction.withFood => l10n.foodWith,
  FoodInstruction.none => '',
};

String _doseSummary(AppLocalizations l10n, DoseEntry entry) {
  final parts = <String>[
    if (entry.medicine.doseLabel.isNotEmpty) entry.medicine.doseLabel,
    if (_foodLabel(l10n, entry.medicine.foodInstruction).isNotEmpty)
      _foodLabel(l10n, entry.medicine.foodInstruction),
  ];
  return parts.join(' • ');
}

class _UpcomingDoseCard extends StatefulWidget {
  const _UpcomingDoseCard({required this.entry});

  final DoseEntry entry;

  @override
  State<_UpcomingDoseCard> createState() => _UpcomingDoseCardState();
}

class _UpcomingDoseCardState extends State<_UpcomingDoseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    // Auto-speak is now handled by AppState._checkAutoSpeak() which runs
    // every 30 seconds from any screen. No need to duplicate here.
  }

  @override
  void didUpdateWidget(_UpcomingDoseCard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final appState = context.read<AppState>();
    final settings = context.read<SettingsController>();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = settings.settings.locale;

    final scheduled = entry.dose.scheduledAt;
    final isDueNow = !scheduled.isAfter(_now.add(const Duration(minutes: 10)));
    final countdown = _countdown(scheduled, _now, l10n);
    final summary = _doseSummary(l10n, entry);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDueNow ? theme.doseDueGradient : theme.doseGradient,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (isDueNow ? theme.doseDueGradient : theme.doseGradient)
                .first
                .withValues(alpha: 0.32),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScaleTransition(
                scale: isDueNow
                    ? CurvedAnimation(
                        parent: _pulseController,
                        curve: Curves.easeInOut,
                      )
                    : const AlwaysStoppedAnimation(1.0),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDueNow
                        ? Icons.notifications_active_rounded
                        : Icons.medication_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.medicine.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (summary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          summary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.speakReminder,
                onPressed: () => _speak(context, entry, l10n, settings),
                icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _GlassChip(
                icon: Icons.schedule_rounded,
                label: AppDateUtils.timeLabel(scheduled, locale),
              ),
              const SizedBox(width: 8),
              _GlassChip(
                icon: countdown.overdue
                    ? Icons.error_outline_rounded
                    : Icons.timelapse_rounded,
                label: countdown.text,
                mono: countdown.mono,
                strong: countdown.overdue,
              ),
              const Spacer(),
              _MarkTakenButton(
                label: l10n.homeMarkAsTaken,
                foreground: (isDueNow
                        ? theme.doseDueGradient
                        : theme.doseGradient)
                    .first,
                onPressed: () async {
                  await appState.markTaken(entry);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
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
                },
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _confirmSkip(context, appState, entry, l10n),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.9),
                padding: const EdgeInsets.symmetric(vertical: 6),
              ),
              child: Text(l10n.homeSkip),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSkip(
    BuildContext context,
    AppState appState,
    DoseEntry entry,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.homeSkipConfirmTitle),
        content: Text(l10n.homeSkipConfirmBody(entry.medicine.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.btnCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.homeSkip),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await appState.markSkipped(entry);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
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
    }
  }

  /// Live countdown for the dose. Within 24h it ticks every second as
  /// `H:MM:SS` (or `-H:MM:SS` once overdue); further out it falls back to a
  /// coarse "in N days" label.
  ({String text, bool mono, bool overdue}) _countdown(
    DateTime scheduled,
    DateTime now,
    AppLocalizations l10n,
  ) {
    final diff = scheduled.difference(now);
    if (diff.inHours >= 24) {
      return (text: l10n.homeInDays(diff.inDays), mono: false, overdue: false);
    }
    if (diff.inDays <= -1) {
      return (
        text: l10n.homeOverdueHours(now.difference(scheduled).inHours),
        mono: false,
        overdue: true,
      );
    }
    // Dose is due now or slightly overdue — show a clear "Due now!" instead
    // of a confusing negative countdown.
    if (diff.isNegative || diff.inMinutes <= 10) {
      return (text: l10n.homeDueNow, mono: false, overdue: diff.isNegative);
    }
    final d = diff;
    String two(int n) => n.toString().padLeft(2, '0');
    final core = d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${d.inMinutes % 60}:${two(d.inSeconds % 60)}';
    return (text: core, mono: true, overdue: false);
  }

  void _speak(
    BuildContext context,
    DoseEntry entry,
    AppLocalizations l10n,
    SettingsController s,
  ) {
    final voice = context.read<AppState>().voice;
    final text = l10n.voiceTimeToTake(
      entry.medicine.name,
      entry.medicine.doseLabel,
    );
    voice.speak(text, s.settings.locale);
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    this.icon,
    required this.label,
    this.mono = false,
    this.strong = false,
  });

  final IconData? icon;
  final String label;

  /// Tabular figures so a ticking countdown doesn't jitter.
  final bool mono;

  /// Higher-contrast fill (used when the dose is overdue).
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 12 : 10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: strong ? 0.30 : 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontFeatures: mono
                  ? const [FontFeature.tabularFigures()]
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkTakenButton extends StatelessWidget {
  const _MarkTakenButton({
    required this.label,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: foreground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      child: Text(label),
    );
  }
}

class _AllDoneCard extends StatelessWidget {
  const _AllDoneCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_rounded, size: 40, color: theme.successColor),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text, style: theme.textTheme.titleMedium),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule filter controls
// ---------------------------------------------------------------------------

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.value, required this.onChanged});

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem(value: null, child: Text(l10n.histAll)),
        PopupMenuItem(
          value: DoseStatus.pending,
          child: Text(l10n.statusPending),
        ),
        PopupMenuItem(value: DoseStatus.taken, child: Text(l10n.statusTaken)),
        PopupMenuItem(value: DoseStatus.missed, child: Text(l10n.statusMissed)),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SlotChips extends StatelessWidget {
  const _SlotChips({required this.selected, required this.onSelected});

  final _TimeSlot selected;
  final ValueChanged<_TimeSlot> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = {
      _TimeSlot.morning: l10n.medTimeSlotMorning,
      _TimeSlot.afternoon: l10n.medTimeSlotAfternoon,
      _TimeSlot.evening: l10n.medTimeSlotEvening,
    };
    return Row(
      children: [
        for (final slot in _TimeSlot.values) ...[
          _SlotChip(
            label: labels[slot]!,
            selected: slot == selected,
            onTap: () => onSelected(slot),
          ),
          if (slot != _TimeSlot.values.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: selected
            ? theme.accentColor
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule list tile
// ---------------------------------------------------------------------------

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.entry,
    required this.locale,
    required this.grace,
    required this.isNext,
    required this.onLog,
  });

  final DoseEntry entry;
  final String locale;
  final Duration grace;
  final bool isNext;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = entry.effectiveStatus(grace, DateTime.now());
    final done = status == DoseStatus.taken || status == DoseStatus.skipped;
    final summary = _doseSummary(l10n, entry);

    final (Color tint, IconData icon) = switch (status) {
      DoseStatus.taken => (theme.successColor, Icons.check_rounded),
      DoseStatus.skipped => (theme.colorScheme.outline, Icons.remove_rounded),
      DoseStatus.missed => (theme.missedColor, Icons.priority_high_rounded),
      DoseStatus.pending => (theme.colorScheme.primary, Icons.medication_rounded),
    };
    final accent = isNext && !done;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: status == DoseStatus.missed
              ? theme.missedColor.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent ? theme.accentColor : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(20),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 22, color: tint),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (summary.isNotEmpty)
                            Text(
                              summary,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Text(
                            entry.medicine.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: done
                                  ? theme.colorScheme.onSurfaceVariant
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppDateUtils.timeLabel(
                                  entry.dose.scheduledAt,
                                  locale,
                                ),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (done)
                      Icon(
                        status == DoseStatus.taken
                            ? Icons.check_circle_rounded
                            : Icons.do_not_disturb_on_rounded,
                        color: tint,
                      )
                    else
                      TextButton(
                        onPressed: onLog,
                        style: TextButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.onSurface,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(l10n.homeLogNow),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            color: theme.colorScheme.primary,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({
    required this.l10n,
    required this.hasMedicines,
    required this.onAddMedicine,
  });

  final AppLocalizations l10n;
  final bool hasMedicines;
  final VoidCallback onAddMedicine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
            ),
            child: Icon(
              hasMedicines
                  ? Icons.event_available_rounded
                  : Icons.medication_rounded,
              size: 46,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            hasMedicines ? l10n.homeEmptySchedule : l10n.homeNoMedicines,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          if (!hasMedicines)
            BigButton(
              label: l10n.medAdd,
              icon: Icons.add_rounded,
              onPressed: onAddMedicine,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily progress summary
// ---------------------------------------------------------------------------

class _ProgressSummary extends StatelessWidget {
  const _ProgressSummary({required this.stats, required this.l10n});

  final AdherenceStats stats;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = stats.adherencePercent;
    final ringColor = pct >= 80 ? theme.successColor : theme.accentColor;

    Widget card({required Widget child}) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: child,
    );

    return IntrinsicHeight(
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: card(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CountRow(
                  value: stats.taken,
                  label: l10n.homeTaken,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _CountRow(
                  value: stats.pending,
                  label: l10n.homeRemaining,
                  color: theme.colorScheme.onSurface,
                ),
                if (stats.missed > 0) ...[
                  const SizedBox(height: 12),
                  _CountRow(
                    value: stats.missed,
                    label: l10n.homeMissed,
                    color: theme.missedColor,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 92,
                  height: 92,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: (pct / 100).clamp(0.0, 1.0),
                          strokeWidth: 9,
                          strokeCap: StrokeCap.round,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(ringColor),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.histAdherence,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          '$value',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Actions grid
// ---------------------------------------------------------------------------

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCalendar,
    required this.onReport,
    required this.onDoctorReport,
    required this.onVoiceMode,
    required this.onVitals,
  });

  final VoidCallback onCalendar;
  final VoidCallback onReport;
  final VoidCallback onDoctorReport;
  final VoidCallback onVoiceMode;
  final VoidCallback onVitals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _QuickActionCard(
          icon: Icons.calendar_month_rounded,
          label: 'Weekly Calendar',
          color: theme.colorScheme.primary,
          onTap: onCalendar,
        ),
        _QuickActionCard(
          icon: Icons.bar_chart_rounded,
          label: 'Adherence Report',
          color: theme.successColor,
          onTap: onReport,
        ),
        _QuickActionCard(
          icon: Icons.local_hospital_rounded,
          label: 'Doctor Report',
          color: theme.colorScheme.tertiary,
          onTap: onDoctorReport,
        ),
        _QuickActionCard(
          icon: Icons.mic_rounded,
          label: 'Voice Mode',
          color: theme.accentColor,
          onTap: onVoiceMode,
        ),
        _QuickActionCard(
          icon: Icons.favorite_rounded,
          label: 'Vitals Log',
          color: theme.missedColor,
          onTap: onVitals,
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
