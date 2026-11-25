import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';

/// Owns the active [AppLocale] and keeps it in [SharedPreferences].
///
/// Follows the same pattern as [ThemeController].
/// Widget and unit tests can create fresh instances so state does not leak.
class LanguageController extends ValueNotifier<AppLocale> {
  // ignore: use_super_parameters
  LanguageController([AppLocale initial = AppLocale.en]) : super(initial);

  static final LanguageController instance = LanguageController();

  /// Preference key. Values are stored as 'en' or 'ne'.
  static const storageKey = 'app_language';

  /// Reads persisted language. Falls back to [AppLocale.en].
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (saved != null) {
        value = AppLocale.fromCode(saved);
      }
    } catch (_) {
      // Storage unavailable in tests or first launch; keep default.
    }
  }

  /// Changes the active locale immediately and persists it.
  Future<void> setLocale(AppLocale locale) async {
    if (value == locale) return;
    value = locale;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, locale.code);
    } catch (_) {
      // Best-effort persistence.
    }

    // Best-effort profile sync when signed in with Firebase.
    _syncToProfile(locale);
  }

  /// Toggles between English and Nepali.
  Future<void> toggle() => setLocale(value.toggled);

  Future<void> _syncToProfile(AppLocale locale) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'preferredLanguage': locale.code,
          'languageUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (_) {
      // Best effort; silently ignore offline or uninitialized Firebase.
    }
  }
}
