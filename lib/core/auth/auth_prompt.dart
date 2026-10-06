import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/login/login_screen.dart';
import '../../services/auth_service.dart';
import '../../services/platform_auth_service.dart';

/// Ensures the user has a valid platform session.
/// If they do not, prompts them to log in using Google.
Future<void> requirePlatformAuth(BuildContext context) async {
  final platformAuth = context.read<PlatformAuthService>();
  if (platformAuth.isSignedIn) return;

  final auth = context.read<AuthService>();

  // If Firebase is already signed in but the platform session expired:
  if (auth.isSignedIn) {
    // Show a loading indicator if we want, but let's just trigger Google Sign-In again
    // silently so it doesn't prompt the user again.
    final idToken = await auth.getGoogleIdTokenSilently();
    if (idToken != null) {
      final success = await platformAuth.signInWithGoogleIdToken(idToken);
      if (success) return;
    }
    
    // If silent token retrieval failed or platform login failed, fallback to prompting.
    final user = await auth.signInWithGoogle();
    if (user != null && auth.lastGoogleIdToken != null) {
      await platformAuth.signInWithGoogleIdToken(auth.lastGoogleIdToken!);
    }
  } else {
    // If not signed in to Firebase at all, route them to the Login Screen as a modal.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(
          onSkip: () => Navigator.of(context).pop(),
          onSignedIn: () {
            // Once they sign in to Firebase in LoginScreen, LoginScreen itself
            // calls platformAuth.signInWithGoogleIdToken, so they are fully authenticated!
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
