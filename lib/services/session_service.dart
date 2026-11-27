import 'package:shared_preferences/shared_preferences.dart';

import 'staff_auth_service.dart';

/// Remembers whether the user (citizen, staff, or admin) chose to stay
/// signed in on this device.
///
/// Firebase Auth already keeps its own session; this preference decides whether
/// the app is allowed to reuse that session on the next launch. It defaults to
/// `true` so a fresh install behaves like Google's apps: sign in once and stay
/// signed in until you explicitly sign out.
class SessionService {
  const SessionService();

  static const rememberKey = 'remember_me';
  static const appLockKey = 'app_lock_enabled';
  static const staffIdentifierKey = 'staff_identifier';
  static const staffIsPhoneKey = 'staff_is_phone';
  static const staffIsSuperAdminKey = 'staff_is_super_admin';

  /// Returns the saved choice, or `true` when nothing has been stored yet.
  Future<bool> loadRememberMe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(rememberKey) ?? true;
    } catch (_) {
      // Storage unavailable (tests, first run, plugin failure): stay signed in.
      return true;
    }
  }

  /// Persists the choice. Failures are non-fatal; the in-memory choice still
  /// applies to the current session.
  Future<void> saveRememberMe(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(rememberKey, value);
    } catch (_) {
      // Best effort only.
    }
  }

  /// Whether the citizen/staff chose to unlock the saved session with the
  /// phone's biometrics or screen lock. Off unless explicitly enabled.
  Future<bool> loadAppLock() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(appLockKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persists the app-lock choice. Disabling is best-effort, like the other
  /// preferences here.
  Future<void> saveAppLock(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(appLockKey, value);
    } catch (_) {
      // Best effort only.
    }
  }

  /// Loads the persisted staff session if staff was remembered.
  Future<StaffSession?> loadStaffSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final identifier = prefs.getString(staffIdentifierKey);
      if (identifier == null || identifier.isEmpty) return null;
      final isPhone = prefs.getBool(staffIsPhoneKey) ?? false;
      final isSuperAdmin = prefs.getBool(staffIsSuperAdminKey) ?? false;
      return StaffSession(
        identifier: identifier,
        isPhone: isPhone,
        isSuperAdmin: isSuperAdmin,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persists staff session details when staff/admin enables Remember Me.
  Future<void> saveStaffSession({
    required String identifier,
    required bool isPhone,
    bool isSuperAdmin = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(staffIdentifierKey, identifier);
      await prefs.setBool(staffIsPhoneKey, isPhone);
      await prefs.setBool(staffIsSuperAdminKey, isSuperAdmin);
    } catch (_) {
      // Best effort only.
    }
  }

  /// Clears stored staff session details.
  Future<void> clearStaffSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(staffIdentifierKey);
      await prefs.remove(staffIsPhoneKey);
      await prefs.remove(staffIsSuperAdminKey);
    } catch (_) {
      // Best effort only.
    }
  }
}
