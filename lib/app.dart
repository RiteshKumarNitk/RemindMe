import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/localization/generated/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'features/history/history_screen.dart';
import 'features/home/home_screen.dart';
import 'features/medicines/medicine_form_screen.dart';
import 'features/medicines/medicines_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/settings/settings_screen.dart';
import 'services/settings_controller.dart';
import 'services/sync/sync_service.dart';
import 'state/app_state.dart';

class MediReminderApp extends StatelessWidget {
  const MediReminderApp({
    super.key,
    required this.appState,
    required this.settings,
    required this.sync,
  });

  final AppState appState;
  final SettingsController settings;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: Consumer<SettingsController>(
        builder: (context, s, _) {
          return MaterialApp(
            title: 'Medicine Reminder',
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

/// Decides between onboarding and the main shell.
class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return settings.onboardingDone
        ? const MainShell()
        : const OnboardingScreen();
  }
}

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
          const SettingsScreen(),
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
            icon: const Icon(Icons.settings_rounded),
            label: l10n.setTitle,
          ),
        ],
      ),
    );
  }
}
