import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the citizen chose to stay signed in on this device.
///
/// Firebase Auth already keeps its own session; this preference decides whether
/// the app is allowed to reuse that session on the next launch. It defaults to
/// `true` so a fresh install behaves like Google's apps: sign in once and stay
/// signed in until you explicitly sign out.
class SessionService {
  const SessionService();

  static const rememberKey = 'remember_me';

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
}
