import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/models/app_update.dart';

void main() {
  group('AppVersion.tryParseTag', () {
    test('parses plain and prefixed tags', () {
      expect(
        AppVersion.tryParseTag('v1.2.3'),
        const AppVersion(major: 1, minor: 2, patch: 3),
      );
      expect(
        AppVersion.tryParseTag('1.2.3'),
        const AppVersion(major: 1, minor: 2, patch: 3),
      );
      expect(
        AppVersion.tryParseTag('V10.20.30'),
        const AppVersion(major: 10, minor: 20, patch: 30),
      );
    });

    test('parses build numbers', () {
      final version = AppVersion.tryParseTag('v1.2.3+4');

      expect(version, isNotNull);
      expect(version!.build, 4);
      expect(version.display, '1.2.3+4');
    });

    test('strips priority suffixes', () {
      const expected = AppVersion(major: 1, minor: 2, patch: 3);

      expect(AppVersion.tryParseTag('v1.2.3-priority'), expected);
      expect(AppVersion.tryParseTag('1.2.3-priority'), expected);
      expect(AppVersion.tryParseTag('v1.2.3+priority'), expected);
      expect(AppVersion.tryParseTag('1.2.3+priority'), expected);
    });

    test('parses build number with priority suffix', () {
      final version = AppVersion.tryParseTag('v1.2.3+9-priority');

      expect(version, isNotNull);
      expect(version!.build, 9);
    });

    test('rejects malformed tags', () {
      expect(AppVersion.tryParseTag(''), isNull);
      expect(AppVersion.tryParseTag('latest'), isNull);
      expect(AppVersion.tryParseTag('v1.2'), isNull);
      expect(AppVersion.tryParseTag('v1.2.3.4'), isNull);
      expect(AppVersion.tryParseTag('v1.2.3-beta'), isNull);
      expect(AppVersion.tryParseTag('version 1.2.3'), isNull);
    });
  });

  group('AppVersion.isPriorityTag', () {
    test('detects priority suffixes case-insensitively', () {
      expect(AppVersion.isPriorityTag('v1.2.3-priority'), isTrue);
      expect(AppVersion.isPriorityTag('v1.2.3+priority'), isTrue);
      expect(AppVersion.isPriorityTag('1.2.3-PRIORITY'), isTrue);
      expect(AppVersion.isPriorityTag('1.2.3+9-priority'), isTrue);
    });

    test('normal releases are not priority', () {
      expect(AppVersion.isPriorityTag('v1.2.3'), isFalse);
      expect(AppVersion.isPriorityTag('v1.2.3+4'), isFalse);
      expect(AppVersion.isPriorityTag('priority-v1.2.3'), isFalse);
    });
  });

  group('selectUpdateFromReleases', () {
    Map<String, dynamic> release({
      required String tag,
      bool draft = false,
      bool prerelease = false,
      bool withApk = true,
      String body = '',
    }) {
      return {
        'tag_name': tag,
        'draft': draft,
        'prerelease': prerelease,
        'body': body,
        'html_url': 'https://github.com/x/y/releases/tag/$tag',
        'assets': withApk
            ? [
                {
                  'name': 'app-release.apk',
                  'size': 51337335,
                  'browser_download_url':
                      'https://example.com/$tag/app-release.apk',
                },
              ]
            : <Map<String, dynamic>>[],
      };
    }

    const installed = AppVersion(major: 1, minor: 0, patch: 0, build: 1);

    test('picks a newer release with an APK asset', () {
      final update = selectUpdateFromReleases(
        [release(tag: 'v1.0.1'), release(tag: 'v1.0.0')],
        installed,
        fallbackReleaseUrl: 'https://github.com/x/y/releases',
      );

      expect(update, isNotNull);
      expect(update!.tag, 'v1.0.1');
      expect(update.version.display, '1.0.1');
      expect(update.apkSize, 51337335);
      expect(update.isPriority, isFalse);
      expect(
        update.apkUrl,
        'https://example.com/v1.0.1/app-release.apk',
      );
    });

    test('marks priority tags', () {
      final update = selectUpdateFromReleases(
        [release(tag: 'v1.0.2-priority')],
        installed,
        fallbackReleaseUrl: 'https://github.com/x/y/releases',
      );

      expect(update!.isPriority, isTrue);
    });

    test('ignores drafts, prereleases and releases without an APK', () {
      final update = selectUpdateFromReleases(
        [
          release(tag: 'v1.1.0', draft: true),
          release(tag: 'v1.2.0', prerelease: true),
          release(tag: 'v1.3.0', withApk: false),
          release(tag: 'not-a-version'),
        ],
        installed,
        fallbackReleaseUrl: 'https://github.com/x/y/releases',
      );

      expect(update, isNull);
    });

    test('ignores releases that are not newer than the installed build', () {
      final update = selectUpdateFromReleases(
        [
          release(tag: 'v1.0.0'),
          release(tag: 'v1.0.0+1'),
          release(tag: 'v0.9.9'),
        ],
        installed,
        fallbackReleaseUrl: 'https://github.com/x/y/releases',
      );

      expect(update, isNull);
    });
  });

  group('AppVersion.isNewerThan', () {
    test('compares major, minor and patch', () {
      expect(
        AppVersion.tryParseTag('v2.0.0')!.isNewerThan(
          AppVersion.tryParseTag('v1.9.9')!,
        ),
        isTrue,
      );
      expect(
        AppVersion.tryParseTag('v1.3.0')!.isNewerThan(
          AppVersion.tryParseTag('v1.2.9')!,
        ),
        isTrue,
      );
      expect(
        AppVersion.tryParseTag('v1.2.4')!.isNewerThan(
          AppVersion.tryParseTag('v1.2.3')!,
        ),
        isTrue,
      );
    });

    test('compares build numbers when the version matches', () {
      expect(
        AppVersion.tryParseTag('v1.2.3+2')!.isNewerThan(
          AppVersion.tryParseTag('v1.2.3+1')!,
        ),
        isTrue,
      );
      expect(
        AppVersion.tryParseTag('v1.2.3+1')!.isNewerThan(
          AppVersion.tryParseTag('v1.2.3+1')!,
        ),
        isFalse,
      );
    });

    test('does not treat older or equal versions as newer', () {
      final current = AppVersion.tryParseTag('v1.2.3')!;

      expect(AppVersion.tryParseTag('v1.2.2')!.isNewerThan(current), isFalse);
      expect(current.isNewerThan(current), isFalse);
    });

    test('a missing build number never wins over an explicit one', () {
      expect(
        AppVersion.tryParseTag('v1.2.3')!.isNewerThan(
          AppVersion.tryParseTag('v1.2.3+1')!,
        ),
        isFalse,
      );
    });
  });
}
