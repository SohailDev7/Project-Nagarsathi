/// A semantic app version parsed from a GitHub release tag.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int? build;

  static const _prioritySuffixes = ['-priority', '+priority'];
  static final _versionPattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?$');

  /// Parses tags like `v1.2.3`, `1.2.3+4`, `v1.2.3-priority`.
  static AppVersion? tryParseTag(String tag) {
    var value = tag.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    for (final suffix in _prioritySuffixes) {
      if (value.toLowerCase().endsWith(suffix)) {
        value = value.substring(0, value.length - suffix.length);
        break;
      }
    }

    final match = _versionPattern.firstMatch(value);
    if (match == null) return null;

    return AppVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: match.group(4) == null ? null : int.parse(match.group(4)!),
    );
  }

  /// True when the tag marks the release as a mandatory update.
  static bool isPriorityTag(String tag) {
    final normalized = tag.trim().toLowerCase();
    return _prioritySuffixes.any(normalized.endsWith);
  }

  bool isNewerThan(AppVersion other) {
    if (major != other.major) return major > other.major;
    if (minor != other.minor) return minor > other.minor;
    if (patch != other.patch) return patch > other.patch;
    if (build != null && other.build != null) return build! > other.build!;
    return false;
  }

  String get display {
    return build == null ? '$major.$minor.$patch' : '$major.$minor.$patch+$build';
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return (build ?? 0).compareTo(other.build ?? 0);
  }

  @override
  bool operator ==(Object other) {
    return other is AppVersion &&
        other.major == major &&
        other.minor == minor &&
        other.patch == patch &&
        other.build == build;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, build);

  @override
  String toString() => 'AppVersion($display)';
}

/// A newer release discovered on GitHub.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.tag,
    required this.notes,
    required this.apkUrl,
    required this.apkSize,
    required this.isPriority,
    required this.releaseUrl,
  });

  final AppVersion version;
  final String tag;
  final String notes;
  final String apkUrl;
  final int apkSize;
  final bool isPriority;
  final String releaseUrl;

  String get sizeLabel {
    if (apkSize <= 0) return '';
    return '${(apkSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Picks the newest applicable release from GitHub's releases payload.
///
/// Skips drafts, prereleases, unparseable tags, releases that are not newer
/// than [current], and releases without an `.apk` asset.
AppUpdate? selectUpdateFromReleases(
  List<Object?> releases,
  AppVersion current, {
  required String fallbackReleaseUrl,
}) {
  for (final item in releases) {
    if (item is! Map<String, dynamic>) continue;
    if (item['draft'] == true || item['prerelease'] == true) continue;

    final tag = item['tag_name'] as String? ?? '';
    final version = AppVersion.tryParseTag(tag);
    if (version == null || !version.isNewerThan(current)) continue;

    final asset = _findApkAsset(item['assets']);
    if (asset == null) continue;

    final downloadUrl = asset['browser_download_url'] as String? ?? '';
    if (downloadUrl.isEmpty) continue;

    return AppUpdate(
      version: version,
      tag: tag,
      notes: (item['body'] as String? ?? '').trim(),
      apkUrl: downloadUrl,
      apkSize: (asset['size'] as num?)?.toInt() ?? 0,
      isPriority: AppVersion.isPriorityTag(tag),
      releaseUrl: item['html_url'] as String? ?? fallbackReleaseUrl,
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
