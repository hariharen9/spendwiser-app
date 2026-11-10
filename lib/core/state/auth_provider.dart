import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../config/google_auth_config.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final authStateProvider = StreamProvider<User?>((ref) {
  try {
    return ref.watch(firebaseAuthProvider).authStateChanges();
  } catch (_) {
    // Firebase is not initialized (tests / pre-bootstrap): stay signed out.
    return Stream<User?>.value(null);
  }
});

final authUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  static bool _googleReady = false;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (name.trim().isNotEmpty) {
      await credential.user?.updateDisplayName(name.trim());
    }
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  Future<void> _ensureGoogleInitialized() async {
    if (_googleReady) return;
    await GoogleSignIn.instance.initialize(
      clientId: defaultTargetPlatform == TargetPlatform.iOS
          ? DefaultFirebaseOptions.ios.iosClientId
          : null,
      serverClientId: googleWebClientId,
    );
    _googleReady = true;
  }

  Future<void> signInWithGoogle() async {
    await _ensureGoogleInitialized();
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw StateError(
        'Google sign-in is not available on this platform build.',
      );
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google did not return an ID token. Check the Android SHA-1 and '
        'server client ID configuration.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _auth.signInWithCredential(credential);
  }

  Future<void> reauthenticate({String? password}) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    final isGoogle = user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    if (isGoogle) {
      await _ensureGoogleInitialized();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError('Google did not return an ID token.');
      }
      await user.reauthenticateWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      return;
    }
    final email = user.email;
    if (email == null || password == null || password.isEmpty) {
      throw StateError('Enter your password to continue.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  Future<void> deleteUser() async {
    await _auth.currentUser?.delete();
  }
}

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.watch(firebaseAuthProvider)),
);

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'That email address looks invalid.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' => 'No account found with that email.',
      'wrong-password' || 'invalid-credential' =>
        'Email or password is incorrect.',
      'email-already-in-use' => 'An account already exists with that email.',
      'weak-password' => 'Use at least 6 characters for the password.',
      'operation-not-allowed' =>
        'Email sign-in is not enabled for this Firebase project.',
      'network-request-failed' => 'Network error. Check your connection.',
      'too-many-requests' => 'Too many attempts. Try again in a moment.',
      'requires-recent-login' =>
        'Please sign in again before deleting your account.',
      _ => error.message ?? 'Authentication failed.',
    };
  }
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Google sign-in was cancelled.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Google sign-in is unavailable right now.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Google sign-in is not configured for this build (SHA-1 or plist missing).',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google sign-in provider is not configured in Firebase.',
      _ => error.description ?? 'Google sign-in failed.',
    };
  }
  if (error is StateError) return error.message;
  return error.toString();
}
