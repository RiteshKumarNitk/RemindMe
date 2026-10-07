import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../services/auth_service.dart';
import '../../services/platform_auth_service.dart';

/// Keeps the Node.js backend session (PlatformAuthService) in sync with the
/// Firebase session (AuthService).
class SessionSyncManager {
  SessionSyncManager(this.authService, this.platformAuth) {
    authService.addListener(_onAuthChanged);
    // Initial sync check
    _syncPlatform();
  }

  final AuthService authService;
  final PlatformAuthService platformAuth;
  bool _isSyncing = false;

  void _onAuthChanged() {
    _syncPlatform();
  }

  Future<void> _syncPlatform() async {
    if (_isSyncing) return;
    
    // If Firebase is signed out, platform should be signed out.
    if (!authService.isSignedIn) {
      if (platformAuth.isSignedIn) {
        await platformAuth.signOut();
      }
      return;
    }

    // If Firebase is signed in but platform is signed out, try to silent login.
    if (authService.isSignedIn && !platformAuth.isSignedIn && !platformAuth.isRestoring) {
      _isSyncing = true;
      try {
        final idToken = await authService.getGoogleIdTokenSilently();
        if (idToken != null) {
          await platformAuth.signInWithGoogleIdToken(idToken);
        }
      } finally {
        _isSyncing = false;
      }
    }
  }

  void dispose() {
    authService.removeListener(_onAuthChanged);
  }
}
