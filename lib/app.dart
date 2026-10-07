import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/localization/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/design_tokens.dart';
import 'features/history/history_screen.dart';
import 'features/home/dose_alarm_screen.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/login/sign_in_gate.dart';
import 'features/medicines/medicine_form_screen.dart';
import 'features/medicines/medicines_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/family_sync_screen.dart';
import 'features/splash/splash_screen.dart';
import 'data/models/dose_entry.dart';
import 'data/models/dose_status.dart';
import 'services/account_deletion_service.dart';
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
    required this.accountDeletion,
  });

  final AppState appState;
  final SettingsController settings;
  final SyncService sync;
  final AuthService auth;
  final AccountDeletionService accountDeletion;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: sync),
        ChangeNotifierProvider.value(value: auth),
        Provider<AccountDeletionService>.value(value: accountDeletion),
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

  /// True when this session entered through "Continue as guest". Guests are
  /// never remembered: the next launch shows the login screen again.
  bool _guest = false;
  late final AuthService _auth = context.read<AuthService>();

  @override
  void initState() {
    super.initState();
    _auth.addListener(_onAuthChanged);
    _init();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _init() async {
    // Branding splash for at least 1.8 s, while Firebase restores any saved
    // Google session in parallel.
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 1800)),
      _auth.waitUntilRestored(),
    ]);
    if (!mounted) return;

    // Only a real Google account counts as signed in. Family sync's
    // anonymous Firebase user used to skip this screen for guests.
    setState(
      () => _stage = _auth.isGoogleSignedIn ? _afterLogin() : _AppStage.login,
    );
  }

  _AppStage _afterLogin() => context.read<SettingsController>().onboardingDone
      ? _AppStage.main
      : _AppStage.onboarding;

  /// Signing out of Google (from Settings) returns to the login screen.
  void _onAuthChanged() {
    // A guest who signs in from the add-medicine sheet is no longer a guest.
    if (_auth.isGoogleSignedIn) _guest = false;
    if (_stage == _AppStage.main && !_guest && !_auth.isGoogleSignedIn) {
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
          onSkip: () => setState(() {
            _guest = true;
            _stage = _afterLogin();
          }),
          onSignedIn: () => setState(() {
            _guest = false;
            _stage = _afterLogin();
          }),
        );
      case _AppStage.onboarding:
        return OnboardingScreen(
          onComplete: () => setState(() => _stage = _AppStage.main),
        );
      case _AppStage.main:
        return const MainShell();
    }
  }
}

enum _AppStage { splash, login, onboarding, main }

/// The four places in the app: Today, my medicines, what happened, my family.
/// Settings and the profile live behind the header avatar, not in the bar.
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

  Future<void> _openAddMedicine() async {
    if (!await ensureGoogleSignIn(context)) return;
    if (!mounted) return;
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
    final isDueNow =
        !next.dose.scheduledAt.isAfter(now.add(const Duration(minutes: 10))) &&
        next.effectiveStatus(settings.graceDuration, now) == DoseStatus.pending;

    // Only show the alarm once per dose, and only when it is actually due.
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
      barrierColor: Colors.black54,
      transitionDuration: AppMotion.normal,
      pageBuilder: (context, animation, secondaryAnimation) {
        return DoseAlarmScreen(entry: entry);
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Check for a due-now alarm on every rebuild.
    _checkAndShowAlarm();

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onAddMedicine: _openAddMedicine),
          const MedicinesScreen(),
          const HistoryScreen(),
          const FamilySyncScreen(embedded: true),
        ],
      ),
      bottomNavigationBar: _AppNavBar(
        index: _index,
        onSelected: (i) => setState(() => _index = i),
        destinations: [
          (Icons.home_rounded, l10n.navHome),
          (Icons.medication_rounded, l10n.navMeds),
          (Icons.history_rounded, l10n.histTitle),
          (Icons.family_restroom_rounded, l10n.navFamily),
        ],
      ),
    );
  }
}

/// Plain, always-labelled navigation bar.
///
/// Icon + word for every destination (never icon-only), a filled pill for the
/// selected item *and* a colour and weight change, so the active tab is obvious
/// without relying on colour alone.
class _AppNavBar extends StatelessWidget {
  const _AppNavBar({
    required this.index,
    required this.onSelected,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<(IconData, String)> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg + 4),
          border: Border.all(color: theme.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: onSelected,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: scheme.primaryContainer,
          indicatorShape: const StadiumBorder(),
          elevation: 0,
          height: AppSizes.navBar,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final (icon, label) in destinations)
              NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(icon, color: scheme.onPrimaryContainer),
                label: label,
                tooltip: label,
              ),
          ],
        ),
      ),
    );
  }
}
