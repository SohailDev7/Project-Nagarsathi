import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/models/citizen_location.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/services/location_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';

class _FakeLocationService extends LocationService {
  @override
  Future<CitizenLocation?> detect() async => const CitizenLocation(
    latitude: 27.6896,
    longitude: 85.3427,
    municipality: 'Kathmandu Metropolitan City',
    ward: 16,
  );
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Nunito');
  for (final weight in [400, 600, 700, 800, 900]) {
    final file = File('assets/fonts/Nunito-$weight.ttf');
    loader.addFont(Future.value(ByteData.view(file.readAsBytesSync().buffer)));
  }
  await loader.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.view(
          File(
            r'C:\flutter\bin\cache\artifacts\material_fonts\materialicons-regular.otf',
          ).readAsBytesSync().buffer,
        ),
      ),
    );
  await icons.load();
}

void main() {
  testWidgets('ward dialog screenshot', (tester) async {
    await _loadFonts();
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: HomeScreen(locationService: _FakeLocationService()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(HomeScreen));
      await precacheImage(const AssetImage('assets/icon/icon.png'), context);
    });
    await tester.tap(find.text('Set your location'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('shots/ward_dialog.png'),
    );

    await tester.tap(find.text("Yes, that's me"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(
      find.byType(HomeScreen),
      matchesGoldenFile('shots/ward_saved.png'),
    );
  });
}
