import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/core/localization/generated/app_localizations.dart';
import 'package:medireminder/data/models/medicine_schedule.dart';
import 'package:medireminder/features/home/home_screen.dart';
import 'package:provider/provider.dart';

import 'test_helpers.dart';

Widget _app(TestEnv env) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: env.settings),
      ChangeNotifierProvider.value(value: env.appState),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: HomeScreen(onAddMedicine: () {})),
    ),
  );
}

void main() {
  testWidgets('home screen shows greeting and empty state', (tester) async {
    late TestEnv env;
    await tester.runAsync(() async {
      env = await TestEnv.create();
      await env.settings.setOnboardingDone(true);
      await env.appState.init();
    });

    await tester.pumpWidget(_app(env));
    await tester.pump();

    expect(
      find.textContaining(RegExp('Good (Morning|Afternoon|Evening)')),
      findsOneWidget,
    );
    expect(find.text('No medicines added yet'), findsOneWidget);
  });

  testWidgets('home shows the next medicine card after adding one', (
    tester,
  ) async {
    late TestEnv env;
    await tester.runAsync(() async {
      env = await TestEnv.create();
      await env.settings.setOnboardingDone(true);
      await env.appState.init();

      // Tomorrow 8:00 AM so the test is time-independent.
      final tomorrow8 = DateTime.now().add(const Duration(days: 1));
      await env.appState.saveMedicine(
        makeMedicine(
          name: 'BP Tablet',
          schedules: [
            MedicineSchedule(
              medicineId: 0,
              hour: tomorrow8.hour,
              minute: tomorrow8.minute,
            ),
          ],
        ),
      );
    });

    await tester.pumpWidget(_app(env));
    await tester.pump();

    expect(find.text('BP Tablet'), findsWidgets);
    expect(find.text('TAKE MEDICINE'), findsOneWidget);
  });
}
