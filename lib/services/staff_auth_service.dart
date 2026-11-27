import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/municipality.dart';
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

/// The signed-in staff member's own record, used to label the workspace with
/// their real name and assigned ward instead of a placeholder.
class StaffProfile {
  const StaffProfile({this.fullName, this.wardLabel});

  final String? fullName;

  /// e.g. `LMC · Ward 5`; null when no ward is on record.
  final String? wardLabel;
}

class StaffSession {
  const StaffSession({
    required this.identifier,
    required this.isPhone,
    this.mustChangePassword = false,
    this.isSuperAdmin = false,
  });

  final String identifier;
  final bool isPhone;
  final bool mustChangePassword;

  /// A super admin manages ward officer accounts and the audit trail; ward
  /// staff work the citizen reports instead.
  final bool isSuperAdmin;
}

class StaffAuthService {
  const StaffAuthService();

  static const _staffCollection = 'staff';
  static const _adminConfigCollection = 'config';
  static const _adminConfigDoc = 'admins';

  /// Used until `config/admins` exists, and whenever it cannot be read, so a
  /// missing document can never lock the last admin out.
  static const _fallbackSuperAdminEmails = <String>{
    'admin@nagarsathi.app',
    'sohailk2064@outlook.com',
  };

  static Set<String> _superAdminEmails = _fallbackSuperAdminEmails;

  static bool get isConfigured => FirebaseBootstrap.isReady;

  /// Sends Firebase's password reset link to a staff or super admin inbox.
  ///
  /// Works before sign-in, so an officer who lost their password can recover
  /// it with nothing but their work email. A missing account is reported as a
  /// success so the form cannot be used to discover which emails exist.
  Future<void> sendPasswordReset(String email) async {
    final clean = email.trim().toLowerCase();
    if (clean.isEmpty || !clean.contains('@')) {
      throw const AuthFailure('Enter your work email first.');
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: clean);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return;
      throw AuthFailure(AuthService.friendlyMessage(error));
    }
  }

  static bool isSuperAdminEmail(String? email) =>
      email != null && _superAdminEmails.contains(email.trim().toLowerCase());

  /// Refreshes the super-admin allowlist from `config/admins`.
  ///
  /// The document wins whenever it has at least one address; otherwise the
  /// built-in pair applies and the signed-in admin seeds the document once, so
  /// the list can then be edited in the Firebase Console with no rebuild and
  /// no rules redeploy.
  static Future<void> loadSuperAdminEmails() async {
    if (!isConfigured) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection(_adminConfigCollection)
          .doc(_adminConfigDoc);
      final snapshot = await docRef.get().timeout(const Duration(seconds: 6));
      final emails = _parseAdminEmails(snapshot.data());
      if (emails.isNotEmpty) {
        _superAdminEmails = emails;
        return;
      }

      final signedIn = FirebaseAuth.instance.currentUser?.email
          ?.trim()
          .toLowerCase();
      if (signedIn == null || !_fallbackSuperAdminEmails.contains(signedIn)) {
        return;
      }
      final seed = _fallbackSuperAdminEmails.toList()..sort();
      await docRef.set({
        'emails': seed,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': signedIn,
      });
      _superAdminEmails = _fallbackSuperAdminEmails;
    } catch (_) {
      // Offline, denied or not seeded yet: keep whatever list is cached.
    }
  }

  static Set<String> _parseAdminEmails(Map<String, dynamic>? data) {
    final raw = data?['emails'];
    if (raw is! List) return const <String>{};
    return raw
        .whereType<String>()
        .map((email) => email.trim().toLowerCase())
        .where((email) => email.contains('@'))
        .toSet();
  }

  /// Reads the signed-in staff member's own officer record so the dashboard can
  /// show who they are and which ward they cover.
  Future<StaffProfile> loadStaffProfile() async {
    if (!isConfigured) return const StaffProfile();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const StaffProfile();

    Map<String, dynamic>? staffData;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_staffCollection)
          .doc(user.uid)
          .get();
      staffData = snapshot.data();
    } on FirebaseException catch (error) {
      if (!_isDeniedOrMissing(error)) rethrow;
    }

    final email = user.email?.trim().toLowerCase();
    final officerData = email == null
        ? null
        : await _findActiveOfficerByEmail(email);

    // The roster copy carries the municipality; the staff mirror may not.
    final details = officerData ?? staffData;
    final rawName = details?['fullName'] ?? details?['name'];
    final name = rawName is String && rawName.trim().isNotEmpty
        ? rawName.trim()
        : null;

    return StaffProfile(fullName: name, wardLabel: _wardLabel(details));
  }

  static String? _wardLabel(Map<String, dynamic>? details) {
    if (details == null) return null;
    final rawWard = details['assignedWard'];
    final ward = rawWard is int ? rawWard : int.tryParse('${rawWard ?? ''}');
    if (ward == null) return null;

    final rawMunicipality =
        details['municipality'] ?? details['municipalityName'];
    if (rawMunicipality == null) return 'Ward $ward';
    return Municipality.fromValue(rawMunicipality).wardLabel(ward);
  }

  /// Whether a stored staff/ward-officer record is explicitly an administrator.
  static bool _isSuperAdminRecord(Map<String, dynamic>? data) =>
      data != null &&
      (data['isSuperAdmin'] == true || data['role'] == 'super_admin');

  /// Whether the signed-in Firebase account is marked as an administrator in
  /// Firestore. Used on cold start when the remembered role is missing or
  /// stale, and the live email alone is not enough to decide.
  Future<bool> hasSuperAdminRecord() async {
    if (!isConfigured) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_staffCollection)
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 6));
      return _isSuperAdminRecord(snapshot.data());
    } catch (_) {
      return false;
    }
  }

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

    // Read the admin list before deciding the role, so adding or removing a
    // super admin in Firestore takes effect on the next sign-in.
    await loadSuperAdminEmails();
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
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(AuthService.friendlyMessage(error));
    } catch (_) {
      throw const AuthFailure('Failed to update password. Try again later.');
    }

    // The password is already changed, so the records that only mirror that
    // fact are best-effort: a denied write must not report a failed password
    // change and leave the officer stuck on the temporary one.
    final firestore = FirebaseFirestore.instance;
    try {
      await firestore.collection(_staffCollection).doc(user.uid).set({
        'mustChangePassword': false,
      }, SetOptions(merge: true));
    } catch (_) {
      // Retried on the next password change; access is granted regardless.
    }

    final emailLower = user.email?.trim().toLowerCase();
    if (emailLower != null && emailLower.isNotEmpty) {
      try {
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
      } catch (_) {
        // The roster copy is cosmetic; the sign-in record above is the gate.
      }
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
        await refreshedUser!.getIdToken(true);
        return StaffSession(
          identifier: email,
          isPhone: false,
          isSuperAdmin: true,
        );
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
      // The rules deny an unreadable or missing `staff` document instead of
      // returning it empty, so a denial here must fall through to the email
      // lookups rather than abort the whole sign-in.
      Map<String, dynamic>? data;
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(_staffCollection)
            .doc(user.uid)
            .get();
        data = snapshot.data();
      } on FirebaseException catch (error) {
        if (!_isDeniedOrMissing(error)) rethrow;
      }

      // Fallback: check by email in staff collection or ward_officers collection
      data ??= await _findStaffByEmail(email);
      data ??= await _findActiveOfficerByEmail(email);

      // A record explicitly marked as an administrator wins over the email
      // allowlist, so a renamed or mistyped login address still opens the
      // console instead of the ward dashboard.
      if (_isSuperAdminRecord(data)) {
        return StaffSession(
          identifier: email,
          isPhone: false,
          isSuperAdmin: true,
        );
      }

      final role = data?['role'];
      if (data == null ||
          (role != 'staff' && role != 'admin') ||
          data['active'] != true) {
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
    } on FirebaseException catch (error) {
      await signOut();
      throw AuthFailure(_staffRecordFailure(email, error));
    } catch (_) {
      await signOut();
      throw AuthFailure(_staffRecordFailure(email, null));
    }
  }

  /// A denied read is the normal answer for a document the caller may not see
  /// (the rules reject rather than return empty); anything else is a real
  /// failure that must still be reported.
  static bool _isDeniedOrMissing(FirebaseException error) =>
      error.code == 'permission-denied' || error.code == 'not-found';

  static Future<Map<String, dynamic>?> _findStaffByEmail(String email) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(_staffCollection)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty ? null : snapshot.docs.first.data();
    } on FirebaseException catch (error) {
      if (!_isDeniedOrMissing(error)) rethrow;
      return null;
    }
  }

  /// Resolves an officer account from the roster when the `staff` mirror was
  /// never written (for example an officer created before the `/staff` write
  /// rule existed). Only active officers become staff sessions.
  static Future<Map<String, dynamic>?> _findActiveOfficerByEmail(
    String email,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ward_officers')
          .where('emailLower', isEqualTo: email)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      final officerData = snapshot.docs.first.data();
      if (officerData['status'] != 'active') return null;
      return {
        ...officerData,
        // Keep an administrator marker; ward officers are plain staff.
        'role': officerData['role'] == 'super_admin' ? 'super_admin' : 'staff',
        'active': true,
      };
    } on FirebaseException catch (error) {
      if (!_isDeniedOrMissing(error)) rethrow;
      return null;
    }
  }

  /// Explains why the staff lookup failed instead of hiding it behind one
  /// generic sentence. The rules deny unreadable `staff` documents rather than
  /// returning them empty, so `permission-denied` is the normal answer for an
  /// email that has no active officer record.
  static String _staffRecordFailure(String email, FirebaseException? error) {
    switch (error?.code) {
      case 'permission-denied':
        return 'No staff record is readable for $email. Super admin accounts '
            'must match the admin allowlist; ward officers need an active '
            'record created by a super admin.';
      case 'unavailable':
      case 'network-request-failed':
      case 'deadline-exceeded':
        return 'Check your internet connection and try again.';
      default:
        return 'We could not check the staff record for $email'
            '${error == null ? '.' : ' (${error.code}).'} Please try again.';
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
          .where('role', whereIn: const ['staff', 'admin'])
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
      if (_isSuperAdminRecord(data)) {
        return StaffSession(
          identifier: phone,
          isPhone: true,
          isSuperAdmin: true,
        );
      }
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
