import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
}

class StaffSession {
  const StaffSession({
    required this.identifier,
    required this.isPhone,
    this.mustChangePassword = false,
  });

  final String identifier;
  final bool isPhone;
  final bool mustChangePassword;
}

class StaffAuthService {
  const StaffAuthService();

  static const _staffCollection = 'staff';
  static const _superAdminEmails = <String>{
    'admin@nagarsathi.app',
    'freefuzxcoj2@gmail.com',
    'sohail@nagarsathi.app',
  };
  static bool get isConfigured => FirebaseBootstrap.isReady;

  static bool isSuperAdminEmail(String? email) =>
      email != null && _superAdminEmails.contains(email.trim().toLowerCase());

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
      throw const AuthFailure(
        'Firebase is not connected. Staff sign-in is unavailable.',
      );
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
      throw const AuthFailure(
        'Firebase is not connected. Phone sign-in is unavailable.',
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
      throw const AuthFailure(
        'Firebase is not connected. Phone sign-in is unavailable.',
      );
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

  Future<void> updateStaffPassword(String newPassword) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AuthFailure('No signed-in staff member found.');
    }
    try {
      await user.updatePassword(newPassword);

      final firestore = FirebaseFirestore.instance;
      // Mark mustChangePassword as false in staff collection
      await firestore.collection(_staffCollection).doc(user.uid).set({
        'mustChangePassword': false,
      }, SetOptions(merge: true));

      // Also mirror update to ward_officers if present
      final emailLower = user.email?.trim().toLowerCase();
      if (emailLower != null && emailLower.isNotEmpty) {
        final query = await firestore
            .collection('ward_officers')
            .where('emailLower', isEqualTo: emailLower)
            .get();
        for (final doc in query.docs) {
          await doc.reference.update({
            'mustChangePassword': false,
            'tempPassword': FieldValue.delete(),
          });
        }
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(AuthService.friendlyMessage(error));
    } catch (e) {
      throw AuthFailure('Failed to update password. Try again later.');
    }
  }

  Future<StaffSession> _loadEmailStaffSession(User? user, String email) async {
    if (user == null) {
      throw const AuthFailure('We could not verify your staff access.');
    }

    if (isSuperAdminEmail(email)) {
      try {
        await user.reload();
        final refreshedUser = FirebaseAuth.instance.currentUser;
        final refreshedEmail = refreshedUser?.email?.trim().toLowerCase();
        if (refreshedEmail != email) {
          await signOut();
          throw const AuthFailure(
            'We could not verify the administrator account.',
          );
        }
        if (refreshedUser?.emailVerified == true) {
          await refreshedUser!.getIdToken(true);
          return StaffSession(identifier: email, isPhone: false);
        }
      } on AuthFailure {
        rethrow;
      } catch (_) {
        await signOut();
        throw const AuthFailure(
          'We could not verify the administrator account.',
        );
      }
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_staffCollection)
          .doc(user.uid)
          .get();
      var data = snapshot.data();

      // Fallback: check by email in staff collection or ward_officers collection
      if (data == null) {
        final emailDoc = await FirebaseFirestore.instance
            .collection(_staffCollection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (emailDoc.docs.isNotEmpty) {
          data = emailDoc.docs.first.data();
        } else {
          final officerDoc = await FirebaseFirestore.instance
              .collection('ward_officers')
              .where('emailLower', isEqualTo: email)
              .limit(1)
              .get();
          if (officerDoc.docs.isNotEmpty) {
            final officerData = officerDoc.docs.first.data();
            if (officerData['status'] == 'active') {
              data = {...officerData, 'role': 'staff', 'active': true};
            }
          }
        }
      }

      if (data == null || data['role'] != 'staff' || data['active'] != true) {
        await FirebaseAuth.instance.signOut();
        throw const AuthFailure(
          'This account is not registered for staff access.',
        );
      }

      final mustChange = data['mustChangePassword'] == true;

      return StaffSession(
        identifier: email,
        isPhone: false,
        mustChangePassword: mustChange,
      );
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
