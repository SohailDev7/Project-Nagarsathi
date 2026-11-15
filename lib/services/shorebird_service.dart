import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

enum PatchUpdateResult {
  upToDate,
  downloaded,
  restartRequired,
  unavailable,
  failed,
}

/// Checks for and downloads Shorebird code-push patches.
///
/// Patches only exist in builds produced with `shorebird release`; in normal
/// builds [ShorebirdUpdater.isAvailable] is false and this is a no-op.
abstract final class ShorebirdService {
  static final _updater = ShorebirdUpdater();

  static Future<PatchUpdateResult> syncPatch() async {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return PatchUpdateResult.unavailable;
    }

    try {
      if (!_updater.isAvailable) return PatchUpdateResult.unavailable;

      final status = await _updater.checkForUpdate();
      switch (status) {
        case UpdateStatus.outdated:
          await _updater.update();
          return PatchUpdateResult.downloaded;
        case UpdateStatus.restartRequired:
          return PatchUpdateResult.restartRequired;
        case UpdateStatus.upToDate:
          return PatchUpdateResult.upToDate;
        case UpdateStatus.unavailable:
          return PatchUpdateResult.unavailable;
      }
    } catch (error) {
      debugPrint('Shorebird patch check failed: $error');
      return PatchUpdateResult.failed;
    }
  }
}
