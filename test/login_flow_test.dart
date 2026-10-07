import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medireminder/core/localization/generated/app_localizations.dart';
import 'package:medireminder/features/login/login_screen.dart';
import 'package:medireminder/features/login/sign_in_gate.dart';
import 'package:medireminder/services/auth_service.dart';
import 'package:provider/provider.dart';

// Firebase isn't initialised in tests, so AuthService behaves like a guest
// (no Google account) — exactly the state these tests need.
Widget _wrap(Widget child) => ChangeNotifierProvider<AuthService>(
  create: (_) => AuthService(),
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  ),
);

void main() {
  testWidgets('login offers guest access and explains the limit', (
    tester,
  ) async {
    var skipped = false;
    await tester.pumpWidget(_wrap(LoginScreen(onSkip: () => skipped = true)));
    await tester.pumpAndSettle();

    expect(find.text('Continue with Guest'), findsOneWidget);
    expect(
      find.text('Guests can explore the app. Sign in to add medicines.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Continue with Guest'));
    await tester.tap(find.text('Continue with Guest'));
    expect(skipped, isTrue);
  });

  testWidgets('guests must sign in before adding a medicine', (tester) async {
    bool? allowed;
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async =>
                    allowed = await ensureGoogleSignIn(context),
                child: const Text('Add medicine'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add medicine'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to add medicines'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(allowed, isFalse);
    expect(find.text('Sign in to add medicines'), findsNothing);
  });
}
