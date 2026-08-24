import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/core/localization/generated/app_localizations.dart';
import 'package:medireminder/data/models/medicine_schedule.dart';
import 'package:medireminder/features/caregiver/caregiver_dashboard_screen.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

Widget _app(TestEnv env) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: env.settings),
      ChangeNotifierProvider.value(value: env.appState),
      ChangeNotifierProvider.value(value: env.sync),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const CaregiverDashboardScreen(),
    ),
  );
}

void main() {
  testWidgets('caregiver dashboard shows weekly adherence and today doses', (
    tester,
  ) async {
    late TestEnv env;
    await tester.runAsync(() async {
      env = await TestEnv.create();
      await env.settings.setSyncSettings(
        syncEnabled: true,
        householdCode: 'ABC123',
        syncRole: 'watcher',
        lastSyncAt: null,
      );
      // A medicine with a dose today at 8:00 AM (time-independent for the
      // within-day assertion: it is always inside "today").
      final now = DateTime.now();
      await env.appState.saveMedicine(
        makeMedicine(
          name: 'BP Tablet',
          schedules: [MedicineSchedule(medicineId: 0, hour: 8, minute: 0)],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(now, isNotNull);
    });

    // Pump inside runAsync so the DB-backed _load() (sync + refresh +
    // history queries, all real async over the FFI database) can complete on
    // the real event loop before the next frame is processed.
    await tester.runAsync(() async {
      await tester.pumpWidget(_app(env));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
    });
    await tester.pump();

    expect(find.text('Family Dashboard'), findsOneWidget);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('Adherence'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('BP Tablet'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
