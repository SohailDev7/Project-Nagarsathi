import 'dart:convert';
import 'dart:io';

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

/// Checks GitHub releases for a newer APK, downloads it and opens the Android
/// package installer.
class UpdateService {
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

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

    for (final item in decoded) {
      if (item is! Map<String, dynamic>) continue;
      if (item['draft'] == true || item['prerelease'] == true) continue;

      final tag = item['tag_name'] as String? ?? '';
      final version = AppVersion.tryParseTag(tag);
      if (version == null || !version.isNewerThan(current)) continue;

      final apkAsset = _findApkAsset(item['assets']);
      if (apkAsset == null) continue;

      final downloadUrl = apkAsset['browser_download_url'] as String? ?? '';
      if (downloadUrl.isEmpty) continue;

      return AppUpdate(
        version: version,
        tag: tag,
        notes: (item['body'] as String? ?? '').trim(),
        apkUrl: downloadUrl,
        apkSize: (apkAsset['size'] as num?)?.toInt() ?? 0,
        isPriority: AppVersion.isPriorityTag(tag),
        releaseUrl: item['html_url'] as String? ?? UpdateConfig.releasesUrl,
      );
    }

    return null;
  }

  Map<String, dynamic>? _findApkAsset(Object? assets) {
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) return asset;
    }
    return null;
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
      rethrow;
    }

    await sink.close();

    if (received == 0) {
      if (await file.exists()) await file.delete();
      throw const UpdateException('The downloaded update file was empty.');
    }

    onProgress?.call(1);
    return file.path;
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
