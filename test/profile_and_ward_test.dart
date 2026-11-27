import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/data/wards_catalog.dart';
import 'package:projectnagarsathi/models/user_profile.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/screens/profile_screen.dart';
import 'package:projectnagarsathi/services/profile_service.dart';
import 'package:projectnagarsathi/utils/validators.dart';

void main() {
  setUp(() {
    ProfileService.instance.setForTest(null);
  });

  group('US-09 Validators', () {
    test('displayName enforces 3 to 40 chars and blocks offensive words', () {
      expect(Validators.displayName('ab'), isNotNull);
      expect(Validators.displayName('a' * 41), isNotNull);
      expect(Validators.displayName('bad shit user'), isNotNull);
      expect(Validators.displayName('Prachi Shahi'), isNull);
      expect(Validators.displayName('abc'), isNull);
      expect(Validators.displayName('a' * 40), isNull);
    });

    test('validateAvatarFile allows JPEG/PNG up to 5MB and rejects others', () {
      expect(
        Validators.validateAvatarFile(
          fileName: 'avatar.gif',
          byteLength: 1024,
        ),
        isNotNull,
      );
      expect(
        Validators.validateAvatarFile(
          fileName: 'avatar.jpg',
          byteLength: Validators.maxAvatarBytes + 1,
        ),
        isNotNull,
      );
      expect(
        Validators.validateAvatarFile(
          fileName: 'avatar.jpeg',
          byteLength: Validators.maxAvatarBytes,
        ),
        isNull,
      );
      expect(
        Validators.validateAvatarFile(
          fileName: 'avatar.png',
          byteLength: 512000,
        ),
        isNull,
      );
    });
  });

  group('US-10 WardsCatalog & UserProfile', () {
    test('WardsCatalog lists all 32 Kathmandu wards with landmarks', () {
      expect(WardsCatalog.kathmanduWards.length, 32);
      expect(WardsCatalog.byNumber(10)?.landmarks, contains('Baneshwor'));
      expect(WardsCatalog.byNumber(16)?.dropdownLabel, contains('Balaju'));
    });

    test('UserProfile serializes and parses channels and homeWard', () {
      const profile = UserProfile(
        uid: 'u1',
        displayName: 'Preeti Tamg',
        homeWard: 10,
        notificationChannels: {
          NotificationChannel.push,
          NotificationChannel.email,
        },
      );
      final parsed = UserProfile.fromMap('u1', profile.toFirestoreMap());
      expect(parsed.displayName, 'Preeti Tamg');
      expect(parsed.homeWard, 10);
      expect(
        parsed.notificationChannels,
        {NotificationChannel.push, NotificationChannel.email},
      );
    });
  });

  group('ProfileScreen & HomeScreen integration', () {
    testWidgets('ProfileScreen saves display name, ward, and channels', (
      tester,
    ) async {
      ProfileService.instance.setForTest(
        const UserProfile(
          uid: 'u1',
          displayName: 'Preeti',
          localPhotoPath: '/tmp/non_existent_avatar.png',
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileScreen(),
        ),
      );
      await tester.pump();

      // Update display name
      await tester.enterText(find.byType(TextFormField).first, 'Prachi Shahi');
      await tester.tap(find.text('Save display name'));
      await tester.pump();
      expect(ProfileService.instance.notifier.value?.displayName, 'Prachi Shahi');

      // Reset avatar to default
      await tester.tap(find.text('Reset avatar'));
      await tester.pump();
      expect(ProfileService.instance.notifier.value?.hasCustomAvatar, isFalse);

      // Select Ward 10 from dropdown and toggle SMS & Email
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pump();
      await tester.tap(find.byKey(const Key('home-ward-dropdown')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.textContaining('Ward 10 —').last);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pump();
      await tester.tap(find.byKey(const Key('channel-checkbox-sms')));
      await tester.pump();

      await tester.tap(find.text('Save preferences'));
      await tester.pump();

      final saved = ProfileService.instance.notifier.value;
      expect(saved?.homeWard, 10);
      expect(saved?.notificationChannels.contains(NotificationChannel.sms), isTrue);
    });

    testWidgets('HomeScreen defaults feed to saved homeWard and updates live', (
      tester,
    ) async {
      ProfileService.instance.setForTest(
        const UserProfile(
          uid: 'u1',
          displayName: 'Preeti Tamg',
          homeWard: 10,
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: HomeScreen(initialName: 'Preeti Tamg'),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Ward 10'), findsWidgets);
      expect(find.textContaining('Preeti Tamg ·'), findsWidgets);

      // Simulate immediate profile update (US-09)
      ProfileService.instance.setForTest(
        const UserProfile(
          uid: 'u1',
          displayName: 'Prachi Shahi',
          homeWard: 10,
        ),
      );
      await tester.pump();

      expect(find.textContaining('Prachi Shahi ·'), findsWidgets);
    });
  });
}
