import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Compile-time Firebase overrides.
///
/// Provide these with `--dart-define` for CI or to keep the Firebase client key
/// out of local config files entirely:
///
/// ```
/// flutter run \
///   --dart-define=FIREBASE_API_KEY=... \
///   --dart-define=FIREBASE_APP_ID=... \
///   --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
///   --dart-define=FIREBASE_PROJECT_ID=...
/// ```
///
/// When none are supplied, Android reads the local (git-ignored)
/// `google-services.json` through the Google Services Gradle plugin.
class FirebaseConfig {
  const FirebaseConfig._();

  static const apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyDOkcMhw7gpQWvHhbecJsOtvp-ToEYXwxU',
  );
  static const appId = String.fromEnvironment(
    'FIREBASE_APP_ID',
    defaultValue: '1:184279715658:android:1bc1acf8500e07e07bfbb3',
  );
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: '184279715658',
  );
  static const projectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'nagar-sathi-23080',
  );
  static const authDomain = String.fromEnvironment(
    'FIREBASE_AUTH_DOMAIN',
    defaultValue: 'nagar-sathi-23080.firebaseapp.com',
  );
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
    defaultValue: 'nagar-sathi-23080.firebasestorage.app',
  );
  static const facebookAppId = String.fromEnvironment(
    'FACEBOOK_APP_ID',
    defaultValue: '1195903589782570',
  );

  /// True when enough values exist to build [options] by hand.
  static bool get isConfigured =>
      apiKey.isNotEmpty && appId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
    authDomain: authDomain.isEmpty ? null : authDomain,
    storageBucket: storageBucket.isEmpty ? null : storageBucket,
  );
}

/// Initializes Firebase once, without ever breaking app start-up.
/// Authentication remains disabled until initialization succeeds.
///
/// Firestore keeps a local cache so a ward officer who loses signal still sees
/// the records they already loaded instead of an error screen.
abstract final class FirebaseBootstrap {
  static bool _ready = false;
  static Object? _error;

  static bool get isReady => _ready;

  /// The initialization failure, if any. Handy while wiring a new project.
  static Object? get error => _error;

  static Future<void> initialize() async {
    if (_ready) return;

    try {
      if (Firebase.apps.isEmpty) {
        if (FirebaseConfig.isConfigured) {
          await Firebase.initializeApp(options: FirebaseConfig.options);
        } else {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        }
      }
      _ready = Firebase.apps.isNotEmpty;
      if (_ready) _enableOfflineCache();
    } catch (error) {
      _ready = false;
      _error = error;
      if (kDebugMode) {
        debugPrint(
          'Firebase is not configured; authentication is disabled. '
          'Run `flutterfire configure` or pass FIREBASE_* dart-defines. '
          'Reason: $error',
        );
      }
    }
  }

  /// Best-effort: an unsupported platform simply keeps the default cache.
  static void _enableOfflineCache() {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Firestore offline cache is unavailable. Reason: $error');
      }
    }
  }
}
