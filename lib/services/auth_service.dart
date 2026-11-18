import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/citizen_location.dart';
import 'firebase_bootstrap.dart';

/// Thrown when an auth request cannot be completed. The message is already
/// citizen-friendly, so screens can show it directly.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Citizen authentication backed by Firebase Auth and Cloud Firestore.
///
/// When Firebase has not been configured yet, every call resolves in a short
/// simulated delay so the existing UI flow stays fully explorable. Once
/// [FirebaseBootstrap.isReady] is true, real accounts are created and each
/// citizen gets a `users/{uid}` profile document.
class AuthService {
  const AuthService();

  static bool get isConfigured => FirebaseBootstrap.isReady;

  static const _users = 'users';

  Future<void> requestEmailOtp(String email) async {
    if (!isConfigured) {
      throw const AuthFailure('Firebase is not configured for email verification.');
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('requestEmailOtp').call({
        'email': email.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthFailure(error.message ?? 'Could not send the verification code.');
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    if (!isConfigured) {
      throw const AuthFailure('Firebase is not configured for email verification.');
    }
    try {
      await FirebaseFunctions.instance.httpsCallable('verifyEmailOtp').call({
        'email': email.trim(),
        'otp': otp.trim(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthFailure(error.message ?? 'Could not verify the code.');
    }
  }

  /// Optional Web OAuth client ID. When empty on Android, `google_sign_in`
  /// reads the web client from `google-services.json` instead.
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static Future<void>? _googleInitialization;

  /// Clears the Firebase session and any cached Google account.
  Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google was not initialised in this session.
    }
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // The local session is already gone.
    }
  }

  /// Reads the confirmed ward from the citizen's Firestore profile.
  Future<CitizenLocation?> loadLocation() async {
    if (!isConfigured) return null;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_users)
          .doc(user.uid)
          .get();
      return CitizenLocation.tryFromMap(snapshot.data()?['location']);
    } catch (_) {
      return null;
    }
  }

  /// Stores the confirmed ward on the citizen's profile.
  ///
  /// Returns `false` in offline demo mode or when the write fails, so the
  /// caller can keep the location for the session and retry later.
  Future<bool> saveLocation(CitizenLocation location) async {
    if (!isConfigured) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      await FirebaseFirestore.instance.collection(_users).doc(user.uid).set({
        'location': location.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> createCitizenAccount({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (!isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      return;
    }

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('We could not finish creating your account.');
      }

      await user.updateDisplayName(name.trim());

      // The account itself is already usable; a failed profile write should
      // not block sign-in, so it is best-effort.
      try {
        await FirebaseFirestore.instance.collection(_users).doc(user.uid).set({
          'uid': user.uid,
          'name': name.trim(),
          'email': email.trim(),
          'phone': (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
          'role': 'citizen',
          'emailVerifiedByOtp': true,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Profile can be backfilled on the next successful sign-in.
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    }
  }

  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    if (!isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      return;
    }

    final email = identifier.trim();
    if (!_looksLikeEmail(email)) {
      throw const AuthFailure(
        'Use your email to sign in. Phone OTP is coming soon.',
      );
    }

    try {
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await _touchProfile(user, provider: 'password');
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    }
  }

  /// Opens the native Android Google account picker and signs the citizen in.
  ///
  /// Returns `false` when the user dismisses the picker. Never falls back to a
  /// browser-based flow.
  Future<bool> signInWithGoogle() async {
    if (!isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      return true;
    }

    await _ensureGoogleInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw const AuthFailure(
        'Google sign-in is only available in the Android app.',
      );
    }

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return false;
      }
      throw AuthFailure(_googleSignInMessage(error));
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthFailure(
        'Google did not return a usable sign-in token. Please try again.',
      );
    }

    try {
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final result = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      final user = result.user;
      if (user != null) {
        await _touchProfile(user, provider: 'google.com');
      }
      return true;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    }
  }

  static Future<void> _ensureGoogleInitialized() async {
    final existing = _googleInitialization;
    if (existing != null) {
      await existing;
      return;
    }

    final future = GoogleSignIn.instance.initialize(
      serverClientId: _googleServerClientId.isEmpty
          ? null
          : _googleServerClientId,
    );
    _googleInitialization = future;
    try {
      await future;
    } on GoogleSignInException catch (error) {
      // Do not cache a failed setup, so a later attempt can retry.
      _googleInitialization = null;
      throw AuthFailure(_googleSignInMessage(error));
    } catch (_) {
      _googleInitialization = null;
      throw const AuthFailure(
        'Google sign-in is not available right now. Please try again.',
      );
    }
  }

  static String _googleSignInMessage(GoogleSignInException error) {
    switch (error.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Google sign-in was cancelled.';
      case GoogleSignInExceptionCode.clientConfigurationError:
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google sign-in is not set up yet for this build.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google sign-in could not open. Please try again.';
      default:
        return 'Google sign-in did not work. Please try again.';
    }
  }

  Future<void> sendPasswordReset(String identifier) async {
    if (!isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 850));
      return;
    }

    final email = identifier.trim();
    if (!_looksLikeEmail(email)) {
      throw const AuthFailure(
        'Password resets go to your email. Add one to continue.',
      );
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    }
  }

  /// Keeps the Firestore copy of the profile in sync after a successful login.
  Future<void> _touchProfile(User user, {required String provider}) async {
    try {
      final doc = FirebaseFirestore.instance.collection(_users).doc(user.uid);
      final snapshot = await doc.get();
      if (snapshot.exists) {
        await doc.update({'updatedAt': FieldValue.serverTimestamp()});
      } else {
        await doc.set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': null,
          'role': 'citizen',
          'authProvider': provider,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Never fail sign-in because of the profile mirror.
    }
  }

  static bool _looksLikeEmail(String value) =>
      value.contains('@') && !value.contains(RegExp(r'\s'));

  static String friendlyMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'That email already has an account. Try signing in.';
      case 'account-exists-with-different-credential':
        return 'That email already uses a password. Sign in that way instead.';
      case 'credential-already-in-use':
        return 'That Google account is already linked to another user.';
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'weak-password':
        return 'Choose a password with at least 8 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your ward office.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      case 'operation-not-allowed':
        return 'Email sign-in is not enabled in Firebase yet.';
      case 'requires-recent-login':
        return 'Please sign in again to finish that change.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
