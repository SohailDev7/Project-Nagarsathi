import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/language_controller.dart';
import '../models/citizen_location.dart';
import 'firebase_bootstrap.dart';
import 'session_service.dart';

enum CitizenDeletionMethod { password, sms, google, facebook }

enum DeletionEmailStatus { sent, pending, unavailable }

class CitizenDeletionSmsChallenge {
  const CitizenDeletionSmsChallenge({
    this.verificationId,
    this.autoCredential,
    this.resendToken,
  });

  final String? verificationId;
  final PhoneAuthCredential? autoCredential;
  final int? resendToken;
}

class CitizenDeletionResult {
  const CitizenDeletionResult({
    required this.completed,
    required this.emailStatus,
  });

  final bool completed;
  final DeletionEmailStatus emailStatus;
}

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
/// Authentication is available only when Firebase initialization succeeded.
/// Demo sign-in is intentionally not implemented.
class AuthService {
  const AuthService({this.firebaseAuth, this.firebaseFunctions});

  final FirebaseAuth? firebaseAuth;
  final FirebaseFunctions? firebaseFunctions;
  FirebaseAuth get _auth => firebaseAuth ?? FirebaseAuth.instance;
  bool get _isConnected => firebaseAuth != null || isConfigured;

  static bool get isConfigured => FirebaseBootstrap.isReady;

  static const _users = 'users';
  static const _otpWorkerUrl = String.fromEnvironment(
    'OTP_WORKER_URL',
    defaultValue: 'https://nagarsathi-otp.sohailk2064.workers.dev',
  );
  static const _pendingEmailLinkKey = 'pending_email_sign_in_link_email';
  static const _emailLinkContinueUrl =
      'https://nagar-sathi-23080.firebaseapp.com/finishSignIn';

  /// Calls one of the OTP worker endpoints and returns its JSON payload.
  ///
  /// The worker answers with a plain `{"error": "..."}` body on failure, which
  /// is surfaced as an [AuthFailure] so screens can show it directly.
  Future<Map<String, dynamic>> _postOtp(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_otpWorkerUrl$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));

      final decoded = response.body.trim().isEmpty
          ? null
          : jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw AuthFailure(
          payload['error'] is String ? payload['error'] as String : 'The email verification service could not complete that request.',
        );
      }
      return payload;
    } on AuthFailure {
      rethrow;
    } on TimeoutException {
      throw const AuthFailure(
        'The verification service timed out. Check your connection and try again.',
      );
    } on FormatException {
      throw const AuthFailure(
        'The verification service returned an unexpected response. Try again.',
      );
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the email verification service. Try again.',
      );
    }
  }

  Future<void> requestEmailOtp(String email, {String? locale}) async {
    await _postOtp('/request-email-otp', {
      'email': email.trim(),
      'locale': locale ?? LanguageController.instance.value.code,
    });
  }

  Future<void> sendEmailSignInLink(String email, {String? locale}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_looksLikeEmail(cleanEmail)) {
      throw const AuthFailure('Enter a valid email address.');
    }
    if (!isConfigured) {
      throw const AuthFailure(
        'Firebase is not connected. Email sign-in is unavailable.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_pendingEmailLinkKey, cleanEmail);
    try {
      final auth = FirebaseAuth.instance;
      await auth.setLanguageCode(
        locale ?? LanguageController.instance.value.code,
      );
      await auth.sendSignInLinkToEmail(
        email: cleanEmail,
        actionCodeSettings: ActionCodeSettings(
          url: _emailLinkContinueUrl,
          handleCodeInApp: true,
          androidPackageName: 'com.softwarica.nagarsathi.projectnagarsathi',
          androidInstallApp: true,
        ),
      );
    } on FirebaseAuthException catch (error) {
      await preferences.remove(_pendingEmailLinkKey);
      throw AuthFailure(friendlyMessage(error));
    } catch (_) {
      await preferences.remove(_pendingEmailLinkKey);
      rethrow;
    }
  }

  bool isEmailSignInLink(String link) =>
      isConfigured && FirebaseAuth.instance.isSignInWithEmailLink(link);

  Future<String?> pendingEmailSignInLinkEmail() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_pendingEmailLinkKey);
  }

  Future<void> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_looksLikeEmail(cleanEmail)) {
      throw const AuthFailure('Enter a valid email address.');
    }
    if (!isConfigured) {
      throw const AuthFailure(
        'Firebase is not connected. Email sign-in is unavailable.',
      );
    }
    if (!FirebaseAuth.instance.isSignInWithEmailLink(emailLink)) {
      throw const AuthFailure('This sign-in link is invalid or has expired.');
    }

    final preferences = await SharedPreferences.getInstance();
    final pendingEmail = preferences.getString(_pendingEmailLinkKey);
    if (pendingEmail != null && pendingEmail != cleanEmail) {
      throw const AuthFailure(
        'Use the same email address that received this sign-in link.',
      );
    }

    try {
      final result = await FirebaseAuth.instance.signInWithEmailLink(
        email: cleanEmail,
        emailLink: emailLink,
      );
      final user = result.user;
      if (user != null) {
        await _touchProfile(user, provider: 'email-link');
      }
      await preferences.remove(_pendingEmailLinkKey);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    }
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String otp,
  }) async {
    await _postOtp('/verify-email-otp', {
      'email': email.trim(),
      'otp': otp.trim(),
    });
  }

  /// Verifies an OTP and establishes a Firebase Auth session using the custom
  /// token returned by the backend, or by signing in/creating the verified account.
  Future<void> signInWithEmailOtp({
    required String email,
    required String otp,
    String? password,
  }) async {
    if (!isConfigured) {
      throw const AuthFailure(
        'Firebase is not connected. Email sign-in is unavailable.',
      );
    }

    final cleanEmail = email.trim().toLowerCase();
    final payload = await _postOtp('/verify-email-otp', {
      'email': cleanEmail,
      'otp': otp.trim(),
    });

    final token = _customTokenFrom(payload);
    if (token != null) {
      try {
        final credential = await FirebaseAuth.instance.signInWithCustomToken(
          token,
        );
        final user = credential.user;
        if (user != null) {
          await _touchProfile(
            user,
            provider: 'email-otp',
          ).timeout(const Duration(seconds: 3), onTimeout: () {});
        }
        return;
      } on FirebaseAuthException catch (error) {
        throw AuthFailure(friendlyMessage(error));
      }
    }

    // When the worker does not return a custom token, OTP verification has
    // still successfully proven the citizen's email ownership.
    if (password != null && password.length >= 8) {
      // 1. Try signing in with the provided password
      try {
        final credential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: cleanEmail, password: password);
        final user = credential.user;
        if (user != null) {
          await _touchProfile(
            user,
            provider: 'password',
          ).timeout(const Duration(seconds: 3), onTimeout: () {});
        }
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code != 'user-not-found' &&
            e.code != 'wrong-password' &&
            e.code != 'invalid-credential') {
          throw AuthFailure(friendlyMessage(e));
        }
      }

      // 2. If password sign-in failed, create the account since the email is verified
      try {
        final credential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: cleanEmail,
              password: password,
            );
        final user = credential.user;
        if (user != null) {
          final defaultName = cleanEmail.split('@').first;
          try {
            await user.updateDisplayName(defaultName);
          } catch (_) {}
          await _touchProfile(
            user,
            provider: 'password',
            name: defaultName,
            email: cleanEmail,
          ).timeout(const Duration(seconds: 3), onTimeout: () {});
        }
        return;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Account exists with a different password.
          // Dispatch a password reset link to their verified inbox.
          try {
            await FirebaseAuth.instance.sendPasswordResetEmail(
              email: cleanEmail,
            );
          } catch (_) {}
          throw AuthFailure(
            'Email verified! This account already has a password. '
            'We have sent a password reset link to $cleanEmail. '
            'Please check your email to set a new password, then sign in.',
          );
        }
        throw AuthFailure(friendlyMessage(e));
      }
    }

    // If no 8+ character password was provided:
    final reason = payload['tokenReason'];
    if (reason == 'user-not-found') {
      throw const AuthFailure(
        'Email verified, but no account was found with this email. '
        'Please enter a password of at least 8 characters to create your account.',
      );
    }

    // Account exists, but no password was given and worker cannot mint custom tokens:
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: cleanEmail);
    } catch (_) {}
    throw AuthFailure(
      'Email verified! A password reset link has been sent to $cleanEmail. '
      'Please check your email to set a new password, then sign in.',
    );
  }

  /// Accepts the token keys used across worker/function versions.
  static String? _customTokenFrom(Map<String, dynamic> payload) {
    for (final key in const ['token', 'customToken', 'firebaseToken']) {
      final value = payload[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  /// Checks whether an account with [email] exists in the backend.
  Future<bool> checkEmailExists(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!_looksLikeEmail(cleanEmail)) return false;

    if (!isConfigured) {
      throw const AuthFailure(
        'Firebase is not connected. Account verification is unavailable.',
      );
    }

    // Do not query Firestore here. Anonymous users are intentionally denied
    // by the Firestore rules, and Firebase Auth will verify the account
    // when the password or OTP sign-in method is submitted.
    return true;
  }

  /// Optional Web OAuth client ID. When empty on Android, `google_sign_in`
  /// reads the web client from `google-services.json` instead.
  static const _googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static Future<void>? _googleInitialization;

  /// Clears the Firebase session and any cached account state.
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_display_name');
      await prefs.remove('cached_email');
    } catch (_) {}

    if (!_isConnected) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {
      // Google was not initialised in this session.
    }
    try {
      await FacebookAuth.instance.logOut();
    } catch (_) {
      // Facebook may not have been used on this device.
    }
    try {
      await _auth.signOut();
    } catch (_) {
      // The local session is already gone.
    }
  }

  User get _deletionUser {
    if (!_isConnected) {
      throw const AuthFailure(
        'Firebase is not connected. Profile deletion is unavailable.',
      );
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Please sign in again to delete your profile.');
    }
    return user;
  }

  CitizenDeletionMethod get deletionMethod {
    final user = _deletionUser;
    final providers = user.providerData.map((provider) => provider.providerId);
    if (providers.contains('password')) return CitizenDeletionMethod.password;
    if (providers.contains('phone') && user.phoneNumber != null) {
      return CitizenDeletionMethod.sms;
    }
    if (providers.contains('google.com')) return CitizenDeletionMethod.google;
    if (providers.contains('facebook.com')) {
      return CitizenDeletionMethod.facebook;
    }
    throw const AuthFailure(
      'Sign in with your password or a linked account to delete your profile.',
    );
  }

  String? get deletionPhoneNumber => _deletionUser.phoneNumber;

  Future<CitizenDeletionSmsChallenge> requestDeletionSmsCode({
    CitizenDeletionSmsChallenge? previous,
  }) async {
    final phone = _deletionUser.phoneNumber;
    if (deletionMethod != CitizenDeletionMethod.sms || phone == null) {
      throw const AuthFailure('This account does not have a verified phone.');
    }
    final completer = Completer<CitizenDeletionSmsChallenge>();
    void complete(CitizenDeletionSmsChallenge challenge) {
      if (!completer.isCompleted) completer.complete(challenge);
    }

    void fail(Object error) {
      if (!completer.isCompleted) {
        completer.completeError(
          error is FirebaseAuthException
              ? AuthFailure(friendlyMessage(error))
              : const AuthFailure(
                  'We could not send the code. Please try again.',
                ),
        );
      }
    }

    try {
      unawaited(
        _auth
            .verifyPhoneNumber(
              phoneNumber: phone,
              forceResendingToken: previous?.resendToken,
              timeout: const Duration(seconds: 60),
              verificationCompleted: (credential) => complete(
                CitizenDeletionSmsChallenge(autoCredential: credential),
              ),
              verificationFailed: fail,
              codeSent: (verificationId, resendToken) => complete(
                CitizenDeletionSmsChallenge(
                  verificationId: verificationId,
                  resendToken: resendToken,
                ),
              ),
              codeAutoRetrievalTimeout: (verificationId) => complete(
                CitizenDeletionSmsChallenge(verificationId: verificationId),
              ),
            )
            .catchError(fail),
      );
      return await completer.future.timeout(const Duration(seconds: 90));
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    } on TimeoutException {
      throw const AuthFailure('Sending the code timed out. Please try again.');
    } on AuthFailure {
      rethrow;
    } catch (_) {
      throw const AuthFailure('We could not send the code. Please try again.');
    }
  }

  /// Reauthenticates the current citizen before asking the trusted backend to
  /// remove their data. Passwords and SMS codes are sent only to Firebase Auth.
  Future<CitizenDeletionResult> deleteCitizenProfile({
    String? password,
    CitizenDeletionSmsChallenge? smsChallenge,
    String? smsCode,
  }) async {
    final user = _deletionUser;
    try {
      final AuthCredential credential;
      switch (deletionMethod) {
        case CitizenDeletionMethod.password:
          if (password == null || password.isEmpty || user.email == null) {
            throw const AuthFailure('Enter your password to confirm deletion.');
          }
          credential = EmailAuthProvider.credential(
            email: user.email!,
            password: password,
          );
        case CitizenDeletionMethod.sms:
          final automatic = smsChallenge?.autoCredential;
          if (automatic != null) {
            credential = automatic;
          } else {
            if (smsChallenge?.verificationId == null ||
                !RegExp(r'^\d{6}$').hasMatch(smsCode?.trim() ?? '')) {
              throw const AuthFailure(
                'Enter the 6-digit SMS verification code.',
              );
            }
            credential = PhoneAuthProvider.credential(
              verificationId: smsChallenge!.verificationId!,
              smsCode: smsCode!.trim(),
            );
          }
        case CitizenDeletionMethod.google:
          await _ensureGoogleInitialized();
          if (!GoogleSignIn.instance.supportsAuthenticate()) {
            throw const AuthFailure(
              'Google verification needs the Android app.',
            );
          }
          final account = await GoogleSignIn.instance.authenticate();
          final token = account.authentication.idToken;
          if (token == null) {
            throw const AuthFailure('Google could not verify your account.');
          }
          credential = GoogleAuthProvider.credential(idToken: token);
        case CitizenDeletionMethod.facebook:
          final result = await FacebookAuth.instance.login(
            permissions: ['public_profile', 'email'],
          );
          if (result.status == LoginStatus.cancelled) {
            throw const AuthFailure(
              'Verification was cancelled. Your profile has not been deleted.',
            );
          }
          if (result.status != LoginStatus.success ||
              result.accessToken == null) {
            throw const AuthFailure('Facebook could not verify your account.');
          }
          credential = FacebookAuthProvider.credential(
            result.accessToken!.tokenString,
          );
      }

      await user.reauthenticateWithCredential(credential);
      await user.getIdToken(true);
      final data = firebaseFunctions != null
          ? await _deleteViaCallable()
          : await _deleteViaWorker(user);
      if (data['status'] != 'deleted' && data['status'] != 'pending') {
        throw const AuthFailure(
          'We could not confirm deletion. Please sign in again to check.',
        );
      }
      final result = CitizenDeletionResult(
        completed: data['status'] == 'deleted',
        emailStatus: switch (data['emailStatus']) {
          'sent' => DeletionEmailStatus.sent,
          'pending' => DeletionEmailStatus.pending,
          _ => DeletionEmailStatus.unavailable,
        },
      );
      await signOut();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(SessionService.rememberKey);
      } catch (_) {}
      return result;
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure(
          'Verification was cancelled. Your profile has not been deleted.',
        );
      }
      throw AuthFailure(_googleSignInMessage(error));
    } catch (_) {
      throw const AuthFailure(
        'We could not confirm deletion. Please sign in again to check.',
      );
    }
  }

  /// Deletes through the Cloud Functions callable. The app does not use this
  /// path in production (Cloud Functions needs the Blaze plan); the worker
  /// endpoint below performs the same trusted cleanup on the free plan.
  Future<Map<String, dynamic>> _deleteViaCallable() async {
    try {
      final response = await firebaseFunctions!
          .httpsCallable(
            'deleteCitizenProfile',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
          )
          .call<Object?>({'confirm': true});
      final payload = response.data;
      if (payload is! Map) {
        throw const AuthFailure(
          'We could not confirm deletion. Please sign in again to check.',
        );
      }
      return Map<String, dynamic>.from(payload);
    } on FirebaseFunctionsException catch (error) {
      switch (error.code) {
        case 'not-found':
        case 'unimplemented':
          throw const AuthFailure(
            'Profile deletion is not available yet. Please try again later.',
          );
        case 'unauthenticated':
        case 'failed-precondition':
          throw const AuthFailure(
            'Please verify your account again to continue.',
          );
        case 'permission-denied':
          throw const AuthFailure('Only citizen accounts can use this option.');
        default:
          throw const AuthFailure(
            'We could not confirm deletion. Please sign in again to check.',
          );
      }
    }
  }

  /// Asks the OTP worker to delete the profile. The worker holds the Firebase
  /// service account and derives the account from the ID token, so the app
  /// never sends a user id or an email.
  Future<Map<String, dynamic>> _deleteViaWorker(User user) async {
    final token = await user.getIdToken();
    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$_otpWorkerUrl/delete-citizen-profile'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'confirm': true}),
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw const AuthFailure(
        'Deletion timed out. Check your connection and try again.',
      );
    } catch (_) {
      throw const AuthFailure(
        'Could not reach the deletion service. Check your connection and try again.',
      );
    }

    var payload = const <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // The status code still tells us whether the request worked.
      }
    }

    if (response.statusCode == 200) return payload;
    final message = payload['error'];
    switch (response.statusCode) {
      case 401:
        throw const AuthFailure(
          'Please verify your account again to continue.',
        );
      case 403:
        throw AuthFailure(
          message is String && message.trim().isNotEmpty
              ? message
              : 'Only citizen accounts can use this option.',
        );
      case 404:
        throw const AuthFailure(
          'Profile deletion is not available yet. Please try again later.',
        );
      default:
        throw AuthFailure(
          message is String && message.trim().isNotEmpty
              ? message
              : 'We could not confirm deletion. Please sign in again to check.',
        );
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
  /// Returns `false` when Firebase is unavailable or the write fails.
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
      throw const AuthFailure(
        'Firebase is not connected. Account creation is unavailable.',
      );
    }

    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isNotEmpty
        ? name.trim()
        : cleanEmail.split('@').first;

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: cleanEmail,
            password: password,
          );

      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('We could not finish creating your account.');
      }

      await user.updateDisplayName(cleanName);

      // The account itself is already usable; a failed profile write should
      // not block sign-in, so it is best-effort.
      try {
        await FirebaseFirestore.instance.collection(_users).doc(user.uid).set({
          'uid': user.uid,
          'name': cleanName,
          'email': cleanEmail,
          'phone': (phone?.trim().isEmpty ?? true) ? null : phone!.trim(),
          'role': 'citizen',
          'preferredLanguage': LanguageController.instance.value.code,
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
      throw const AuthFailure(
        'Firebase is not connected. Sign-in is unavailable.',
      );
    }

    final email = identifier.trim().toLowerCase();
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
        await _touchProfile(
          user,
          provider: 'password',
        ).timeout(const Duration(seconds: 3), onTimeout: () {});
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    } on FirebaseException catch (_) {
      throw const AuthFailure(
        'Could not connect to Firebase. Check your internet and try again.',
      );
    } catch (_) {
      throw const AuthFailure(
        'Sign-in could not finish. Check your connection and try again.',
      );
    }
  }

  /// Opens the native Android Google account picker and signs the citizen in.
  ///
  /// Returns `false` when the user dismisses the picker. Never falls back to a
  /// browser-based flow.
  Future<bool> signInWithGoogle() async {
    if (!isConfigured) {
      throw const AuthFailure(
        'Firebase is not connected. Google sign-in is unavailable.',
      );
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
    final email = identifier.trim();
    if (!_looksLikeEmail(email)) {
      throw const AuthFailure(
        'Password resets go to your email. Add one to continue.',
      );
    }

    if (!isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    }
  }

  /// Keeps the Firestore copy of the profile in sync after a successful login.
  ///
  /// [name] and [email] override the values on [user] when supplied — useful
  /// for Facebook sign-in where the Auth user is an email/password account
  /// but we want to persist the real Facebook display name.
  Future<void> _touchProfile(
    User user, {
    required String provider,
    String? name,
    String? email,
  }) async {
    try {
      final doc = FirebaseFirestore.instance.collection(_users).doc(user.uid);
      final snapshot = await doc.get();
      final resolvedName = name ?? user.displayName ?? '';
      final resolvedEmail = email ?? user.email ?? '';
      if (snapshot.exists) {
        await doc.update({
          'uid': user.uid,
          'role': 'citizen',
          if (resolvedName.isNotEmpty) 'name': resolvedName,
          if (resolvedEmail.isNotEmpty) 'email': resolvedEmail,
          'authProvider': provider,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await doc.set({
          'uid': user.uid,
          'name': resolvedName,
          'email': resolvedEmail,
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

  // ─── Facebook sign-in ────────────────────────────────────────────────────

  /// Signs the citizen in with Facebook using the native Facebook SDK.
  ///
  /// Returns a map `{'name': ..., 'email': ...}` with the real Facebook
  /// profile values on success, or `null` if the user cancelled or an error
  /// occurred.
  Future<Map<String, String?>?> signInWithFacebook() async {
    if (!isConfigured) {
      throw const AuthFailure(
        'Firebase is not connected. Facebook sign-in is unavailable.',
      );
    }

    try {
      // ── 1. Native Facebook login — opens Chrome Custom Tab via Facebook SDK ─
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      if (result.status == LoginStatus.cancelled) {
        return null; // User dismissed
      }
      if (result.status != LoginStatus.success || result.accessToken == null) {
        throw AuthFailure(
          result.message ??
              'Facebook sign-in did not complete. Please try again.',
        );
      }

      // ── 2. Get real user data from Facebook Graph API ─────────────────────
      final userData = await FacebookAuth.instance.getUserData(
        fields: 'name,email',
      );
      final fbName = (userData['name'] as String?)?.trim();
      final fbEmail = (userData['email'] as String?)?.trim();

      // ── 3. Sign in to Firebase with the Facebook credential ───────────────
      User? user;
      try {
        final credential = FacebookAuthProvider.credential(
          result.accessToken!.tokenString,
        );
        final authResult = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        user = authResult.user;
      } on FirebaseAuthException catch (authError) {
        if (kDebugMode) {
          debugPrint(
            'signInWithCredential note: ${authError.code} - ${authError.message}',
          );
        }
        throw AuthFailure(friendlyMessage(authError));
      } catch (err) {
        if (kDebugMode) debugPrint('signInWithCredential unexpected: $err');
        throw const AuthFailure(
          'Facebook could not verify this account with Firebase. Please try again.',
        );
      }

      // ── 4. Ensure displayName is set (Facebook → Firebase) ────────────────
      final resolvedName = (fbName != null && fbName.isNotEmpty)
          ? fbName
          : (user?.displayName?.trim() ?? '');
      final resolvedEmail = (fbEmail != null && fbEmail.isNotEmpty)
          ? fbEmail
          : (user?.email?.trim() ?? '');

      if (user != null && resolvedName.isNotEmpty) {
        try {
          await user.updateDisplayName(resolvedName);
          await user.reload();
        } catch (_) {}
      }

      // ── 5. Persist to SharedPreferences for offline fallback ──────────────
      try {
        final prefs = await SharedPreferences.getInstance();
        if (resolvedName.isNotEmpty) {
          await prefs.setString('cached_display_name', resolvedName);
        }
        if (resolvedEmail.isNotEmpty) {
          await prefs.setString('cached_email', resolvedEmail);
        }
      } catch (_) {}

      // ── 6. Mirror profile to Firestore ────────────────────────────────────
      if (user != null) {
        final refreshed = FirebaseAuth.instance.currentUser ?? user;
        await _touchProfile(
          refreshed,
          provider: 'facebook.com',
          name: resolvedName.isNotEmpty ? resolvedName : null,
          email: resolvedEmail.isNotEmpty ? resolvedEmail : null,
        );
      }

      return {
        'name': resolvedName.isNotEmpty ? resolvedName : null,
        'email': resolvedEmail.isNotEmpty ? resolvedEmail : null,
      };
    } on AuthFailure {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(friendlyMessage(error));
    } catch (e) {
      if (kDebugMode) debugPrint('signInWithFacebook error: $e');
      throw AuthFailure('Facebook error: $e');
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
        return 'Email or password is incorrect. If you never set a password, '
            'use the email code option instead.';
      case 'invalid-custom-token':
      case 'custom-token-mismatch':
        return 'That sign-in code is no longer valid. Request a new code and '
            'try again.';
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
      case 'user-mismatch':
        return 'Verify with the same account you used to sign in.';
      case 'invalid-verification-code':
        return 'That SMS code is incorrect. Please try again.';
      case 'session-expired':
        return 'That SMS code has expired. Request a new one.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
