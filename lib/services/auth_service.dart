import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
        await _touchProfile(user);
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
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
  Future<void> _touchProfile(User user) async {
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
