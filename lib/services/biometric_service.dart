import 'package:local_auth/local_auth.dart';

/// The device-level security methods NagarSathi can use for App Lock.
///
/// Android and iOS expose these through the system biometric prompt, so the
/// app never reads a fingerprint or face scan itself. It only learns whether a
/// screen lock exists and whether the phone accepted the challenge.
class BiometricAvailability {
  const BiometricAvailability({
    required this.deviceSupported,
    required this.biometrics,
  });

  /// A phone with no enrolled biometrics and no PIN/pattern/passcode.
  static const unsupported = BiometricAvailability(
    deviceSupported: false,
    biometrics: <BiometricType>[],
  );

  /// True when the phone can fall back to its PIN, pattern, or passcode.
  final bool deviceSupported;

  /// Biometrics currently enrolled on the phone.
  final List<BiometricType> biometrics;

  bool get supportsBiometrics => biometrics.isNotEmpty;

  /// True when at least one way to unlock the phone is available.
  bool get isSupported => deviceSupported || supportsBiometrics;

  bool get hasFace => biometrics.contains(BiometricType.face);
  bool get hasFingerprint => biometrics.contains(BiometricType.fingerprint);
  bool get hasIris => biometrics.contains(BiometricType.iris);

  /// True when the platform reports only a generic strong/weak biometric.
  bool get hasGenericBiometric =>
      supportsBiometrics && !hasFace && !hasFingerprint && !hasIris;

  /// Human-readable list used in copy such as
  /// "Face unlock, fingerprint, and screen lock PIN".
  String get methodSummary {
    final methods = <String>[
      if (hasFace) 'face unlock',
      if (hasFingerprint) 'fingerprint',
      if (hasIris) 'iris unlock',
      if (hasGenericBiometric) 'biometric unlock',
      if (deviceSupported) 'screen lock PIN',
    ];
    if (methods.isEmpty) return 'No screen lock set up';
    if (methods.length == 1) return _capitalize(methods.single);
    if (methods.length == 2) {
      return '${_capitalize(methods[0])} and ${methods[1]}';
    }
    final head = methods.sublist(0, methods.length - 1).join(', ');
    return '${_capitalize(head)}, and ${methods.last}';
  }

  /// Shorter label for buttons.
  String get actionLabel {
    if (hasFace && hasFingerprint) {
      return 'Unlock with face or fingerprint';
    }
    if (hasFace) return 'Unlock with face';
    if (hasFingerprint) return 'Unlock with fingerprint';
    if (hasIris) return 'Unlock with iris';
    if (hasGenericBiometric) return 'Unlock with biometrics';
    if (deviceSupported) return 'Unlock with device PIN';
    return 'Unlock';
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

/// Result of a device-lock challenge, with a citizen-friendly explanation for
/// the common failure cases.
class BiometricOutcome {
  const BiometricOutcome.success() : success = true, message = null;

  const BiometricOutcome.failure(this.message) : success = false;

  final bool success;
  final String? message;
}

/// Wraps `local_auth` so screens do not have to deal with platform channels,
/// plugin exceptions, or device-specific wording.
class BiometricService {
  BiometricService({LocalAuthentication? authentication})
    : _authentication = authentication ?? LocalAuthentication();

  final LocalAuthentication _authentication;

  /// Reads what this phone can currently do. Never throws; unsupported or
  /// plugin-less environments simply report [BiometricAvailability.unsupported].
  Future<BiometricAvailability> availability() async {
    try {
      final deviceSupported = await _authentication.isDeviceSupported();
      List<BiometricType> biometrics = const <BiometricType>[];
      try {
        biometrics = await _authentication.getAvailableBiometrics();
      } catch (_) {
        // A phone can still support a PIN without exposing biometrics.
      }
      return BiometricAvailability(
        deviceSupported: deviceSupported,
        biometrics: biometrics,
      );
    } catch (_) {
      return BiometricAvailability.unsupported;
    }
  }

  /// Shows the system prompt. Biometrics are preferred, with the phone's PIN,
  /// pattern, or passcode available as the fallback.
  Future<BiometricOutcome> authenticate({
    String reason = 'Unlock NagarSathi',
  }) async {
    try {
      final passed = await _authentication.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      if (passed) return const BiometricOutcome.success();
      return const BiometricOutcome.failure(
        'That did not verify. Try again, or sign in with your password.',
      );
    } on LocalAuthException catch (error) {
      return BiometricOutcome.failure(_messageFor(error.code));
    } catch (_) {
      return const BiometricOutcome.failure(
        'The device lock could not open. Try again, or sign in with your '
        'password.',
      );
    }
  }

  static String _messageFor(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
      case LocalAuthExceptionCode.timeout:
        return 'Unlock cancelled. Try again when you are ready.';
      case LocalAuthExceptionCode.temporaryLockout:
        return 'Too many attempts. Wait a moment, then try again.';
      case LocalAuthExceptionCode.biometricLockout:
        return 'Biometrics are locked. Unlock your phone with its PIN, then '
            'try again.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'This phone no longer has a screen lock. Sign in with your '
            'password to continue.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'No fingerprint or face is enrolled. Add one in phone settings '
            'or use your screen lock PIN.';
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'This phone has no biometric hardware. Use its screen lock PIN '
            'instead.';
      case LocalAuthExceptionCode.userRequestedFallback:
        return 'Use your phone\'s screen lock PIN to continue.';
      case LocalAuthExceptionCode.uiUnavailable:
        return 'The device lock could not open right now. Try again.';
      case LocalAuthExceptionCode.authInProgress:
        return 'An unlock is already in progress.';
      case LocalAuthExceptionCode.biometricHardwareTemporarilyUnavailable:
        return 'Biometrics are busy right now. Try again in a moment.';
      case LocalAuthExceptionCode.deviceError:
      case LocalAuthExceptionCode.unknownError:
        return 'The device lock could not open. Try again, or sign in with '
            'your password.';
    }
  }
}
