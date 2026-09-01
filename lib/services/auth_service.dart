import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Manages Firebase Authentication with Google Sign-In.
/// Handles Firebase-not-configured gracefully — the app works fully offline.
class AuthService extends ChangeNotifier {
  AuthService() {
    _tryInitFirebase();
  }

  FirebaseAuth? _auth;
  GoogleSignIn? _google;
  bool _firebaseAvailable = false;
  bool _firebaseInitializing = true;
  String? _error;
  String? _debugInfo;

  bool get firebaseAvailable => _firebaseAvailable;
  bool get isSignedIn => user != null;
  bool get hasError => _error != null;
  String? get error => _error;
  bool get initializing => _firebaseInitializing;
  String? get debugInfo => _debugInfo;

  User? get user => _auth?.currentUser;
  String get displayName => user?.displayName ?? '';
  String get email => _auth?.currentUser?.email ?? '';
  String get photoUrl => _auth?.currentUser?.photoURL ?? '';
  String get uid => _auth?.currentUser?.uid ?? '';

  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream.empty();

  /// Safely try to initialize Firebase Auth. If Firebase wasn't initialized
  /// in main.dart (missing google-services.json), the app continues fully
  /// offline — auth features are just disabled.
  void _tryInitFirebase() async {
    _firebaseInitializing = true;
    try {
      // Check if Firebase was actually initialized (by Firebase.initializeApp
      // in main.dart). Firebase.app() throws if not initialized.
      final app = Firebase.app();
      _debugInfo = 'Firebase app: ${app.name}, project: ${app.options.projectId}';

      _auth = FirebaseAuth.instance;
      _google = GoogleSignIn(
        // On Android, the client ID comes from google-services.json automatically.
        // On web, client ID comes from <meta> tag in index.html.
        scopes: ['email', 'profile'],
      );

      // Verify the auth instance is functional
      final currentUser = _auth!.currentUser;
      if (currentUser != null) {
        _debugInfo = '${_debugInfo!}\nSigned in as: ${currentUser.email}';
      } else {
        _debugInfo = '${_debugInfo!}\nNo user signed in';
      }

      _firebaseAvailable = true;
      developer.log('Firebase Auth initialized: $_debugInfo', name: 'Auth');
    } catch (e) {
      _firebaseAvailable = false;
      _auth = null;
      _google = null;
      _debugInfo = 'Firebase init error: $e';
      developer.log('Firebase Auth not available: $e', name: 'Auth', error: e);
    }
    _firebaseInitializing = false;
    notifyListeners();
  }

  /// Signs in with Google. Returns the [User] on success, or null on
  /// cancellation / error. Provides specific error messages for common issues.
  Future<User?> signInWithGoogle() async {
    if (!_firebaseAvailable || _auth == null || _google == null) {
      _error = 'Firebase is not configured. Please set up Firebase first.';
      notifyListeners();
      return null;
    }

    try {
      _error = null;
      _debugInfo = 'Starting Google sign-in...';

      final account = await _google!.signIn();
      if (account == null) {
        // User cancelled the sign-in dialog
        _debugInfo = 'User cancelled sign-in';
        developer.log('Google sign-in cancelled by user', name: 'Auth');
        notifyListeners();
        return null;
      }

      _debugInfo = 'Got Google account: ${account.email}';
      developer.log('Got Google account: ${account.email}', name: 'Auth');

      final auth = await account.authentication;
      if (auth.accessToken == null || auth.idToken == null) {
        _error = 'Failed to get Google credentials. Please try again.';
        _debugInfo = 'Auth tokens null: accessToken=${auth.accessToken != null}, idToken=${auth.idToken != null}';
        developer.log('Google auth tokens null', name: 'Auth');
        notifyListeners();
        return null;
      }

      _debugInfo = 'Got auth tokens, creating credential...';
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      _debugInfo = 'Signing in to Firebase...';
      final result = await _auth!.signInWithCredential(credential);

      if (result.user == null) {
        _error = 'Firebase sign-in returned no user. Please try again.';
        _debugInfo = 'Firebase signInWithCredential returned null user';
        notifyListeners();
        return null;
      }

      _debugInfo = 'Signed in successfully: ${result.user!.email}';
      _error = null;
      developer.log('Signed in: ${result.user!.email}', name: 'Auth');
      notifyListeners();
      return result.user;
    } on FirebaseAuthException catch (e) {
      // Firebase-specific errors with actionable messages
      _error = _firebaseAuthErrorMessage(e);
      _debugInfo = 'FirebaseAuthException: ${e.code} - ${e.message}';
      developer.log('Firebase auth error: ${e.code}', name: 'Auth', error: e);
      notifyListeners();
      return null;
    } catch (e) {
      _error = _generalErrorMessage(e);
      _debugInfo = 'Error: ${e.runtimeType} - $e';
      developer.log('Google sign-in failed: $e', name: 'Auth', error: e);
      notifyListeners();
      return null;
    }
  }

  /// Translates Firebase Auth error codes to user-friendly messages.
  String _firebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid credentials. The Firebase project may not have Google Sign-In enabled. Check Firebase Console → Authentication → Sign-in method.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled. Go to Firebase Console → Authentication → Sign-in method → Enable Google.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few minutes and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'web-internal-error':
      case 'internal-error':
        return 'Internal Firebase error. Make sure google-services.json is up to date and SHA-1 is registered in Firebase Console.';
      case 'app-not-authorized':
        return 'App not authorized. Make sure SHA-1 fingerprint is registered in Firebase Console → Project Settings → Android app.';
      default:
        return 'Sign-in failed (${e.code}). Check Firebase Console configuration.';
    }
  }

  /// Translates general exceptions to user-friendly messages.
  String _generalErrorMessage(dynamic e) {
    final msg = e.toString();
    if (msg.contains('network') || msg.contains('SocketException')) {
      return 'No internet connection. Please check your network.';
    }
    if (msg.contains('SHA') || msg.contains('certificate')) {
      return 'SHA-1 fingerprint mismatch. Register your debug SHA-1 in Firebase Console.';
    }
    if (msg.contains('api_key') || msg.contains('API_KEY')) {
      return 'Invalid API key. Download a fresh google-services.json from Firebase Console.';
    }
    if (msg.contains('play-services') || msg.contains('Google Play Services')) {
      return 'Google Play Services not available. Update Google Play Services on your device.';
    }
    return 'Sign-in failed. Please check your internet connection and try again.';
  }

  /// Signs out from both Google and Firebase.
  Future<void> signOut() async {
    try {
      await _google?.signOut();
      await _auth?.signOut();
      _error = null;
      _debugInfo = 'Signed out';
      developer.log('Signed out', name: 'Auth');
      notifyListeners();
    } catch (e) {
      _debugInfo = 'Sign-out error: $e';
      developer.log('Sign-out failed: $e', name: 'Auth', error: e);
    }
  }

  /// Updates the user's display name.
  Future<void> updateDisplayName(String name) async {
    if (_auth?.currentUser == null) return;
    try {
      await _auth!.currentUser!.updateDisplayName(name);
      notifyListeners();
    } catch (e) {
      developer.log('updateDisplayName failed: $e', name: 'Auth', error: e);
    }
  }

  /// Runs a diagnostic check on the Firebase configuration.
  /// Returns a map of check results for the debug panel.
  Future<Map<String, String>> runDiagnostics() async {
    final results = <String, String>{};

    // Check Firebase initialization
    try {
      final app = Firebase.app();
      results['Firebase'] = '✅ Connected (project: ${app.options.projectId})';
    } catch (e) {
      results['Firebase'] = '❌ Not initialized: $e';
      return results;
    }

    // Check Firebase Auth
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user != null) {
        results['Auth'] = '✅ Signed in as ${user.email}';
      } else {
        results['Auth'] = '⚠️ Not signed in (this is normal)';
      }
    } catch (e) {
      results['Auth'] = '❌ Auth not available: $e';
    }

    // Check Google Sign-In
    try {
      GoogleSignIn(scopes: ['email', 'profile']);
      results['Google Sign-In'] = '✅ Plugin loaded';
    } catch (e) {
      results['Google Sign-In'] = '❌ Plugin error: $e';
    }

    // Check connectivity
    try {
      results['Debug Info'] = _debugInfo ?? 'No debug info yet';
    } catch (_) {}

    return results;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
