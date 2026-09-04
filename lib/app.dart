import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/localization/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/history/history_screen.dart';
import 'features/home/dose_alarm_screen.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/medicines/medicine_form_screen.dart';
import 'features/medicines/medicines_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/splash/splash_screen.dart';
import 'data/models/dose_entry.dart';
import 'data/models/dose_status.dart';
import 'services/auth_service.dart';
import 'services/settings_controller.dart';
import 'services/sync/sync_service.dart';
import 'state/app_state.dart';

class MediReminderApp extends StatelessWidget {
  const MediReminderApp({
    super.key,
    required this.appState,
    required this.settings,
    required this.sync,
    required this.auth,
  });

  final AppState appState;
  final SettingsController settings;
  final SyncService sync;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: auth),
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) {
          return MaterialApp(
            title: 'DoseWise',
            debugShowCheckedModeBanner: false,
            locale: Locale(s.settings.locale),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: s.themeMode,
            home: const RootScreen(),
          );
        },
      ),
    );
  }
}

/// App root: Splash → Login → Onboarding → Main
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  _AppStage _stage = _AppStage.splash;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Show splash for at least 1.5 seconds for branding
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final auth = context.read<AuthService>();
    final settings = context.read<SettingsController>();

    if (auth.isSignedIn || settings.onboardingDone) {
      // User already signed in or completed onboarding — go to main
      setState(() => _stage = _AppStage.main);
    } else {
      // First launch — show login
      setState(() => _stage = _AppStage.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _AppStage.splash:
        return const SplashScreen();
      case _AppStage.login:
        return LoginScreen(
          onSkip: () {
            setState(() => _stage = _AppStage.onboarding);
          },
          onSignedIn: () {
            setState(() => _stage = _AppStage.onboarding);
          },
        );
      case _AppStage.onboarding:
        return OnboardingScreen(
          onComplete: () {
            setState(() => _stage = _AppStage.main);
          },
        );
      case _AppStage.main:
        return const MainShell();
    }
  }
}

enum _AppStage { splash, login, onboarding, main }

/// Bottom-navigation shell hosting the four main screens.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;
  int _lastAlarmId = -1; // Track which dose we've already shown the alarm for

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when returning to the app so changes made from notifications
    // (taken / skipped / snoozed) appear immediately.
    if (state == AppLifecycleState.resumed) {
      final appState = context.read<AppState>();
      appState.refreshPermissionStatus();
      appState.refresh();
      appState.restartAutoSpeak();
      context.read<SyncService>().syncNow();
    }
  }

  void _openAddMedicine() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MedicineFormScreen()));
  }



  void _checkAndShowAlarm() {
    final appState = context.read<AppState>();
    final settings = context.read<SettingsController>();
    final next = appState.nextDose;
    if (next == null) return;

    final now = DateTime.now();
    final isDueNow = !next.dose.scheduledAt.isAfter(now.add(const Duration(minutes: 10))) &&
        next.effectiveStatus(settings.graceDuration, now) == DoseStatus.pending;

    // Only show alarm once per dose, and only when due now
    if (isDueNow && next.dose.id != _lastAlarmId) {
      _lastAlarmId = next.dose.id!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAlarmOverlay(next);
      });
    }
  }

  void _showAlarmOverlay(DoseEntry entry) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'alarm',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return DoseAlarmScreen(entry: entry);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_NavSpec>[
      _NavSpec(Icons.home_rounded, l10n.navHome),
      _NavSpec(Icons.medication_rounded, l10n.navMeds),
      _NavSpec(Icons.history_rounded, l10n.histTitle),
      _NavSpec(Icons.person_rounded, l10n.navProfile),
    ];

    // Check for due-now alarm on every rebuild
    _checkAndShowAlarm();

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onAddMedicine: _openAddMedicine),
          const MedicinesScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton(
              onPressed: _openAddMedicine,
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      bottomNavigationBar: _PillNavBar(
        items: items,
        selectedIndex: _index,
        onSelected: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavSpec {
  const _NavSpec(this.icon, this.label);
  final IconData icon;
  final String label;
}

/// Bottom navigation styled to the product mockups: a floating white bar with
/// a filled "pill" behind the selected destination.
class _PillNavBar extends StatelessWidget {
  const _PillNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavSpec> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < items.length; i++)
              if (i == selectedIndex)
                _PillNavItem(
                  spec: items[i],
                  selected: true,
                  onTap: () => onSelected(i),
                )
              else
                Expanded(
                  child: _PillNavItem(
                    spec: items[i],
                    selected: false,
                    onTap: () => onSelected(i),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _PillNavItem extends StatelessWidget {
  const _PillNavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final _NavSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 18 : 6,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: selected
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(spec.icon, size: 22, color: theme.colorScheme.onPrimary),
                  const SizedBox(width: 8),
                  Text(
                    spec.label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    spec.icon,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
