import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../utils/validators.dart';
import 'auth_service.dart';
import 'firebase_bootstrap.dart';

class StaffPhoneChallenge {
  const StaffPhoneChallenge({
    required this.phoneNumber,
    this.verificationId,
    this.resendToken,
    this.autoCredential,
  });

  final String phoneNumber;
  final String? verificationId;
  final int? resendToken;
  final PhoneAuthCredential? autoCredential;

  bool get isDemo => verificationId == StaffAuthService.demoVerificationId;
}

class StaffSession {
  const StaffSession({required this.identifier, required this.isPhone});

  final String identifier;
  final bool isPhone;
}

class StaffAuthService {
  const StaffAuthService();

  static const _staffCollection = 'staff';
  static const demoVerificationId = 'demo-staff-verification';
  static const demoCode = '123456';

  static bool get isConfigured => FirebaseBootstrap.isReady;

  static Future<void> signOut() async {
    if (!isConfigured) return;
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      return;
    }
  }

  Future<StaffSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (!isConfigured) {
      if (!kDebugMode) {
        throw const AuthFailure('Staff sign-in is temporarily unavailable.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 850));
      return StaffSession(identifier: normalizedEmail, isPhone: false);
    }

    late UserCredential result;
    try {
      result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(AuthService.friendlyMessage(error));
    }

    return _loadEmailStaffSession(result.user, normalizedEmail);
  }

  Future<StaffPhoneChallenge> sendPhoneCode(
    String rawPhone, {
    StaffPhoneChallenge? previous,
  }) async {
    final phone = Validators.normalizeNepaliPhone(rawPhone);
    if (phone == null) {
      throw const AuthFailure('Enter a valid Nepali mobile number');
    }

    if (!isConfigured) {
      if (!kDebugMode) {
        throw const AuthFailure('Staff sign-in is temporarily unavailable.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 850));
      return StaffPhoneChallenge(
        phoneNumber: phone,
        verificationId: demoVerificationId,
        resendToken: previous?.resendToken,
      );
    }

    final completer = Completer<StaffPhoneChallenge>();

    void complete(StaffPhoneChallenge challenge) {
      if (!completer.isCompleted) completer.complete(challenge);
    }

    void fail(FirebaseAuthException error) {
      if (!completer.isCompleted) {
        completer.completeError(AuthFailure(_friendlyPhoneMessage(error)));
      }
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: previous?.resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) {
          complete(
            StaffPhoneChallenge(phoneNumber: phone, autoCredential: credential),
          );
        },
        verificationFailed: fail,
        codeSent: (verificationId, resendToken) {
          complete(
            StaffPhoneChallenge(
              phoneNumber: phone,
              verificationId: verificationId,
              resendToken: resendToken,
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          complete(
            StaffPhoneChallenge(
              phoneNumber: phone,
              verificationId: verificationId,
              resendToken: previous?.resendToken,
            ),
          );
        },
      );
    } on FirebaseAuthException catch (error) {
      fail(error);
    } catch (_) {
      if (!completer.isCompleted) {
        completer.completeError(
          const AuthFailure('We could not send the code. Please try again.'),
        );
      }
    }

    return completer.future;
  }

  Future<StaffSession> verifyPhoneOtp({
    required StaffPhoneChallenge challenge,
    String? code,
  }) async {
    if (!isConfigured) {
      if (!kDebugMode) {
        throw const AuthFailure('Staff sign-in is temporarily unavailable.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 850));
      if (code?.trim() != demoCode) {
        throw const AuthFailure('That code is not right. Try again.');
      }
      return StaffSession(identifier: challenge.phoneNumber, isPhone: true);
    }

    final credential = challenge.autoCredential;
    if (credential == null &&
        (challenge.verificationId == null ||
            challenge.verificationId!.isEmpty)) {
      throw const AuthFailure('Request a new code to continue.');
    }

    late UserCredential result;
    try {
      result = await FirebaseAuth.instance.signInWithCredential(
        credential ??
            PhoneAuthProvider.credential(
              verificationId: challenge.verificationId!,
              smsCode: code!.trim(),
            ),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_friendlyPhoneMessage(error));
    }

    return _loadStaffSession(result.user, challenge.phoneNumber);
  }

  Future<StaffSession> _loadEmailStaffSession(User? user, String email) async {
    if (user == null) {
      throw const AuthFailure('We could not verify your staff access.');
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_staffCollection)
          .doc(user.uid)
          .get();
      final data = snapshot.data();

      if (data == null || data['role'] != 'staff' || data['active'] != true) {
        await FirebaseAuth.instance.signOut();
        throw const AuthFailure(
          'This account is not registered for staff access.',
        );
      }

      return StaffSession(identifier: email, isPhone: false);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      await signOut();
      throw const AuthFailure(
        'We could not check your staff record. Contact your ward office.',
      );
    }
  }

  Future<StaffSession> _loadStaffSession(User? user, String phone) async {
    if (user == null) {
      throw const AuthFailure('We could not verify your staff access.');
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_staffCollection)
          .where('phone', isEqualTo: phone)
          .where('role', isEqualTo: 'staff')
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        await FirebaseAuth.instance.signOut();
        throw const AuthFailure(
          'This number is not registered for staff access.',
        );
      }

      final data = snapshot.docs.first.data();
      if (data['active'] != true || data['role'] != 'staff') {
        await FirebaseAuth.instance.signOut();
        throw const AuthFailure(
          'This number is not registered for staff access.',
        );
      }

      return StaffSession(identifier: phone, isPhone: true);
    } on AuthFailure {
      rethrow;
    } catch (_) {
      await signOut();
      throw const AuthFailure(
        'We could not check your staff record. Contact your ward office.',
      );
    }
  }

  static String _friendlyPhoneMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-phone-number':
        return 'Enter a valid Nepali mobile number';
      case 'invalid-verification-code':
        return 'That code is not right. Try again.';
      case 'invalid-verification-id':
      case 'session-expired':
        return 'That code has expired. Request a new one.';
      case 'quota-exceeded':
        return 'Too many codes requested. Please try again later.';
      case 'operation-not-allowed':
        return 'Phone sign-in is not enabled in Firebase yet.';
      case 'credential-already-in-use':
      case 'account-exists-with-different-credential':
        return 'This number is linked to another account. Contact your ward office.';
      default:
        return AuthService.friendlyMessage(error);
    }
  }
}
