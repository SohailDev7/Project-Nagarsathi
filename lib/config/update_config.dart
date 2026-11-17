/// Configuration for GitHub release based updates and Shorebird.
///
/// Override the repository or supply a token at build time:
/// `flutter build apk --dart-define=GITHUB_TOKEN=...`
abstract final class UpdateConfig {
  static const owner = String.fromEnvironment(
    'GITHUB_REPO_OWNER',
    defaultValue: 'SohailDev7',
  );
  static const repo = String.fromEnvironment(
    'GITHUB_REPO_NAME',
    defaultValue: 'Project-Nagarsathi',
  );
  static const githubToken = String.fromEnvironment(
    'GITHUB_TOKEN',
    defaultValue: '',
  );

  /// Minimum gap between automatic GitHub release checks. Small on purpose so
  /// opening the app always re-checks; the manual check bypasses it entirely.
  static const checkInterval = Duration(minutes: 1);

  /// How long "Later" postpones a non-priority update.
  static const snoozeDuration = Duration(hours: 24);

  static bool get isConfigured => owner.isNotEmpty && repo.isNotEmpty;

  static Uri get releasesApi =>
      Uri.https('api.github.com', '/repos/$owner/$repo/releases');

  static String get releasesUrl => 'https://github.com/$owner/$repo/releases';
}
