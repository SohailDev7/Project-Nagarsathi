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

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const messagingSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
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
}
