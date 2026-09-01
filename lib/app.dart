import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/localization/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/medicines/medicine_form_screen.dart';
import 'features/medicines/medicines_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/splash/splash_screen.dart';
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
      context.read<SyncService>().syncNow();
    }
  }

  void _openAddMedicine() {
    setState(() => _index = 1);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MedicineFormScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onAddMedicine: _openAddMedicine),
          const MedicinesScreen(),
          const HistoryScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_rounded),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.medication_rounded),
            label: l10n.medTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_rounded),
            label: l10n.histTitle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_rounded),
            label: l10n.navProfile,
          ),
        ],
      ),
    );
  }
}
