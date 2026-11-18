import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/models/citizen_location.dart';
import 'package:projectnagarsathi/screens/home_screen.dart';
import 'package:projectnagarsathi/services/location_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';

class _FakeLocationService extends LocationService {
  _FakeLocationService(this.location);

  final CitizenLocation location;

  @override
  Future<CitizenLocation?> detect() async => location;
}

const _kmcWard16 = CitizenLocation(
  latitude: 27.6896,
  longitude: 85.3427,
  municipality: 'Kathmandu Metropolitan City',
  ward: 16,
);

Future<void> _pumpHome(
  WidgetTester tester, {
  required LocationService locationService,
}) async {
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
      home: HomeScreen(locationService: locationService),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detected ward is confirmed and shown on the pill', (
    tester,
  ) async {
    await _pumpHome(tester, locationService: _FakeLocationService(_kmcWard16));

    expect(find.text('Set your location'), findsOneWidget);

    await tester.tap(find.text('Set your location'));
    await tester.pumpAndSettle();

    expect(find.text('Are you from'), findsOneWidget);
    expect(find.text('KMC WARD -16'), findsOneWidget);
    expect(find.text('Kathmandu Metropolitan City'), findsOneWidget);

    await tester.tap(find.text("Yes, that's me"));
    await tester.pumpAndSettle();

    expect(find.text('KMC WARD -16'), findsOneWidget);
    expect(find.text('Ward saved for this session.'), findsOneWidget);
  });

  testWidgets('declining the ward keeps the location unset', (tester) async {
    await _pumpHome(tester, locationService: _FakeLocationService(_kmcWard16));

    await tester.tap(find.text('Set your location'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not quite'));
    await tester.pumpAndSettle();

    expect(find.text('Set your location'), findsOneWidget);
    expect(
      find.text('No problem. Tap the location pill to try again.'),
      findsOneWidget,
    );
  });
}
