import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Owns the selected [ThemeMode] and keeps it in shared preferences.
///
/// The app uses [instance]; tests can create their own controller so a
/// selection never leaks between cases. Every platform-storage call is
/// guarded: widget tests do not register the shared_preferences plugin and
/// the app must still start (and render) when storage is unavailable.
class ThemeController extends ValueNotifier<ThemeMode> {
  // TODO: restore ThemeMode.system as default when US-01 PR 2 (screen migration) is complete.
  // ignore: use_super_parameters
  ThemeController([ThemeMode initial = ThemeMode.light]) : super(initial);

  static final ThemeController instance = ThemeController();

  /// Preference key. Values are stored as [ThemeMode.name]:
  /// `system`, `light`, or `dark`.
  static const storageKey = 'theme_mode';

  /// Reads the persisted mode. Missing or unknown values fall back to
  /// [ThemeMode.light].
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      value = _decode(prefs.getString(storageKey));
    } catch (_) {
      // Storage unavailable (tests, first run, plugin failure): keep the
      // current value rather than blocking start-up.
    }
  }

  /// Applies [mode] immediately, then persists it best-effort.
  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, mode.name);
    } catch (_) {
      // The in-memory selection still applies for this session.
    }
  }

  static ThemeMode _decode(String? raw) {
    for (final mode in ThemeMode.values) {
      if (mode.name == raw) return mode;
    }
    return ThemeMode.light;
  }
}
