import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/core/localization/generated/app_localizations.dart';
import 'package:medireminder/features/medicines/medicine_form_screen.dart';
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
      home: const MedicineFormScreen(),
    ),
  );
}

void main() {
  Future<TestEnv> setup(WidgetTester tester) async {
    // Tall viewport so the whole form fits and the Save button is built.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late TestEnv env;
    await tester.runAsync(() async {
      env = await TestEnv.create();
      await env.appState.init();
    });
    await tester.pumpWidget(_app(env));
    await tester.pump();
    return env;
  }

  testWidgets('form validates the medicine name', (tester) async {
    await setup(tester);

    // Section label "Medicine name" is shown once; tap Save with an empty
    // name and the validation error adds a second occurrence.
    expect(find.text('Medicine name'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Medicine name'), findsNWidgets(2));
  });

  testWidgets('form saves a medicine with a name', (tester) async {
    final env = await setup(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Calcium');
    await tester.runAsync(() async {
      await tester.tap(find.text('Save'));
      await tester.pump();
    });

    final meds = await tester.runAsync(() => env.medicineRepository.getAll());
    expect(meds, isNotNull);
    expect(meds!.length, 1);
    expect(meds.first.name, 'Calcium');
  });

  testWidgets('quick time slots add and remove reminder times', (tester) async {
    await setup(tester);

    // A new form defaults to one 8:00 AM reminder (the Morning slot).
    expect(find.text('8:00 AM'), findsOneWidget);

    // Tap "Evening": the 6:00 PM reminder appears.
    await tester.tap(find.text('Evening'));
    await tester.pump();
    expect(find.text('6:00 PM'), findsOneWidget);

    // Tap it again: the 6:00 PM reminder is removed (toggle).
    await tester.tap(find.text('Evening'));
    await tester.pump();
    expect(find.text('6:00 PM'), findsNothing);

    // Tapping "Morning" removes the default 8:00 AM reminder.
    await tester.tap(find.text('Morning'));
    await tester.pump();
    expect(find.text('8:00 AM'), findsNothing);
  });

  testWidgets('unit quick-pick fills the unit field', (tester) async {
    await setup(tester);

    await tester.tap(find.text('tablet'));
    await tester.pump();
    expect(find.widgetWithText(TextFormField, 'tablet'), findsOneWidget);
  });
}
