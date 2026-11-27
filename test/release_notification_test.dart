import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:projectnagarsathi/models/app_update.dart';
import 'package:projectnagarsathi/services/release_notification_service.dart';
import 'package:projectnagarsathi/widgets/update_gate.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppUpdate sampleUpdate({
    String version = '1.2.0+5',
    String notes = '## Highlights\n- Faster citizen dashboard\n- Light theme polish',
  }) {
    return AppUpdate(
      version: AppVersion.tryParseTag(version)!,
      tag: 'v$version',
      notes: notes,
      apkUrl:
          'https://github.com/SohailDev7/Project-Nagarsathi/releases/download/v$version/app-release.apk',
      apkSize: 1024 * 1024 * 24,
      isPriority: false,
      releaseUrl:
          'https://github.com/SohailDev7/Project-Nagarsathi/releases/tag/v$version',
    );
  }

  group('ReleaseNotificationService', () {
    test('detects release messages from FCM data payloads', () {
      expect(
        ReleaseNotificationService.isReleaseMessage({'type': 'github_release'}),
        isTrue,
      );
      expect(
        ReleaseNotificationService.isReleaseMessage({'tag': 'v1.2.0'}),
        isTrue,
      );
      expect(
        ReleaseNotificationService.isReleaseMessage({'type': 'chat_message'}),
        isFalse,
      );
      expect(ReleaseNotificationService.isReleaseMessage({}), isFalse);
    });

    test('builds crisp notification copy from GitHub AppUpdate notes', () {
      final copy = ReleaseNotificationService.copyFromAppUpdate(sampleUpdate());
      expect(copy.version, '1.2.0+5');
      expect(copy.title, 'NagarSathi v1.2.0+5 is available');
      expect(copy.body, contains('Highlights'));
      expect(copy.body, contains('Tap to update'));

      final blankNotesCopy = ReleaseNotificationService.copyFromAppUpdate(
        sampleUpdate(notes: '   \n\n  '),
      );
      expect(blankNotesCopy.body, contains('GitHub Releases'));
    });

    test('extracts copy from RemoteMessage with notification or data fallback', () {
      final withNotification = RemoteMessage(
        notification: const RemoteNotification(
          title: 'Release v2.0.0 out now',
          body: 'Tap to install the latest APK.',
        ),
        data: const {'type': 'github_release', 'tag': 'v2.0.0'},
      );
      final copy1 = ReleaseNotificationService.copyFromRemoteMessage(
        withNotification,
      );
      expect(copy1.title, 'Release v2.0.0 out now');
      expect(copy1.body, 'Tap to install the latest APK.');
      expect(copy1.version, '2.0.0');

      final dataOnly = RemoteMessage(
        data: const {
          'type': 'github_release',
          'tag': 'v2.1.0+12',
          'notes': 'Includes ward map fixes.',
        },
      );
      final copy2 = ReleaseNotificationService.copyFromRemoteMessage(dataOnly);
      expect(copy2.title, 'NagarSathi v2.1.0+12 is available');
      expect(copy2.body, 'Includes ward map fixes.');
      expect(copy2.version, '2.1.0+12');
    });

    test('notifyIfNewRelease sends once per release version and skips duplicates', () async {
      SharedPreferences.setMockInitialValues({});
      final sent = <ReleaseNotificationCopy>[];
      final v1 = sampleUpdate(version: '1.2.0+5');
      final v2 = sampleUpdate(version: '1.3.0+6');

      final first = await ReleaseNotificationService.instance.notifyIfNewRelease(
        v1,
        showNotification: (copy) async => sent.add(copy),
      );
      final duplicate = await ReleaseNotificationService.instance.notifyIfNewRelease(
        v1,
        showNotification: (copy) async => sent.add(copy),
      );
      final upgrade = await ReleaseNotificationService.instance.notifyIfNewRelease(
        v2,
        showNotification: (copy) async => sent.add(copy),
      );

      expect(first, isTrue);
      expect(duplicate, isFalse);
      expect(upgrade, isTrue);
      expect(sent.map((e) => e.version), ['1.2.0+5', '1.3.0+6']);
    });

    testWidgets('UpdateGate initializes cleanly without platform plugins', (
      tester,
    ) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: UpdateGate(
            navigatorKey: navKey,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(UpdateGate), findsOneWidget);
    });
  });
}
