import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/update_config.dart';
import '../models/app_update.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when the user cancels a download in progress.
class UpdateCancelled implements Exception {
  const UpdateCancelled();

  @override
  String toString() => 'Update cancelled.';
}

/// Checks GitHub releases for a newer APK, downloads it and opens the Android
/// package installer.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool _cancelRequested = false;

  /// Stops the download that is currently running, if any.
  void cancelDownload() => _cancelRequested = true;

  static const _lastCheckKey = 'github_update_last_check';
  static const _snoozeVersionKey = 'github_update_snooze_version';
  static const _snoozeUntilKey = 'github_update_snooze_until';

  Future<AppUpdate?> checkForUpdate({bool force = false}) async {
    if (!Platform.isAndroid || !UpdateConfig.isConfigured) return null;

    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final lastCheck = prefs.getInt(_lastCheckKey) ?? 0;
      final elapsed =
          DateTime.now().millisecondsSinceEpoch - lastCheck;
      if (elapsed < UpdateConfig.checkInterval.inMilliseconds) return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final buildNumber = packageInfo.buildNumber.trim();
    final current = AppVersion.tryParseTag(
      buildNumber.isEmpty
          ? packageInfo.version
          : '${packageInfo.version}+$buildNumber',
    );
    if (current == null) return null;
    debugPrint('Update check: installed ${current.display}');

    final response = await _client
        .get(
          UpdateConfig.releasesApi,
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
            'User-Agent': 'NagarSathi',
            if (UpdateConfig.githubToken.isNotEmpty)
              'Authorization': 'Bearer ${UpdateConfig.githubToken}',
          },
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw UpdateException(
        'GitHub releases request failed (HTTP ${response.statusCode}).',
      );
    }

    await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return null;

    final update = selectUpdateFromReleases(
      decoded,
      current,
      fallbackReleaseUrl: UpdateConfig.releasesUrl,
    );

    if (update == null) {
      debugPrint('Update check: up to date');
      return null;
    }

    debugPrint('Update check: found ${update.tag}');
    return update;
  }

  Future<bool> shouldPrompt(AppUpdate update) async {
    if (update.isPriority) return true;

    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString(_snoozeVersionKey);
    final until = prefs.getInt(_snoozeUntilKey) ?? 0;
    final snoozed =
        version == update.version.display &&
        DateTime.now().millisecondsSinceEpoch < until;
    return !snoozed;
  }

  Future<void> snooze(AppUpdate update) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_snoozeVersionKey, update.version.display);
    await prefs.setInt(
      _snoozeUntilKey,
      DateTime.now().add(UpdateConfig.snoozeDuration).millisecondsSinceEpoch,
    );
  }

  Future<String> downloadApk(
    AppUpdate update, {
    void Function(double progress)? onProgress,
  }) async {
    _cancelRequested = false;
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'nagarsathi-${update.version.display}.apk',
    );
    if (await file.exists()) await file.delete();

    final request = http.Request('GET', Uri.parse(update.apkUrl));
    request.headers['User-Agent'] = 'NagarSathi';
    if (UpdateConfig.githubToken.isNotEmpty &&
        update.apkUrl.contains('github')) {
      request.headers['Authorization'] = 'Bearer ${UpdateConfig.githubToken}';
    }

    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw UpdateException(
        'Download failed (HTTP ${response.statusCode}).',
      );
    }

    final total = response.contentLength ?? update.apkSize;
    final sink = file.openWrite();
    var received = 0;
    var lastReported = -1.0;

    try {
      await for (final chunk in response.stream) {
        if (_cancelRequested) throw const UpdateCancelled();
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final progress = (received / total).clamp(0.0, 1.0).toDouble();
          if (progress - lastReported >= 0.01 || progress == 1.0) {
            lastReported = progress;
            onProgress?.call(progress);
          }
        }
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      _cancelRequested = false;
      rethrow;
    }

    await sink.close();

    if (received == 0) {
      if (await file.exists()) await file.delete();
      throw const UpdateException('The downloaded update file was empty.');
    }

    if (total > 0 && received < total) {
      if (await file.exists()) await file.delete();
      throw const UpdateException(
        'The download stopped early. Check your connection and try again.',
      );
    }

    if (!await _looksLikeApk(file)) {
      await file.delete();
      throw const UpdateException(
        'The downloaded file is not a valid APK. Try again, or install it '
        'manually from the GitHub release.',
      );
    }

    onProgress?.call(1);
    return file.path;
  }

  /// Guards against handing a truncated file or an HTML error page to Android,
  /// which would otherwise fail with "There was a problem parsing the package".
  Future<bool> _looksLikeApk(File file) async {
    if (!await file.exists() || await file.length() < 1024) return false;

    final handle = await file.open();
    try {
      final magic = await handle.read(4);
      return magic.length == 4 &&
          magic[0] == 0x50 && // P
          magic[1] == 0x4B && // K
          magic[2] == 0x03 &&
          magic[3] == 0x04;
    } finally {
      await handle.close();
    }
  }

  Future<void> installApk(String path) async {
    final result = await OpenFilex.open(
      path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw UpdateException(
        result.type == ResultType.permissionDenied
            ? "Android blocked the installer. Allow 'Install unknown apps' "
                  'for NagarSathi in Settings, then try again.'
            : "Couldn't open the Android installer: ${result.message}",
      );
    }
  }

  Future<void> openReleasePage(AppUpdate update) async {
    final opened = await launchUrl(
      Uri.parse(update.releaseUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) {
      throw const UpdateException('Could not open the release page.');
    }
  }

  void dispose() => _client.close();
}
