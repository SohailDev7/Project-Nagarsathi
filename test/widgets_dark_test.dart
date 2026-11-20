import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';
import 'package:projectnagarsathi/widgets/ns_auth_heading.dart';
import 'package:projectnagarsathi/widgets/ns_back_button.dart';
import 'package:projectnagarsathi/widgets/ns_background.dart';
import 'package:projectnagarsathi/widgets/ns_card.dart';
import 'package:projectnagarsathi/widgets/ns_chip.dart';
import 'package:projectnagarsathi/widgets/ns_city_art.dart';
import 'package:projectnagarsathi/widgets/ns_google_button.dart';
import 'package:projectnagarsathi/widgets/ns_logo.dart';
import 'package:projectnagarsathi/widgets/ns_outline_button.dart';
import 'package:projectnagarsathi/widgets/ns_segmented_control.dart';
import 'package:projectnagarsathi/widgets/ns_step_progress.dart';
import 'package:projectnagarsathi/widgets/ns_text_field.dart';

double _relativeLuminance(Color color) {
  double channel(double value) {
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> _pumpInTheme(
  WidgetTester tester,
  Widget child,
  Brightness brightness, {
  bool settle = true,
}) async {
  // Honour reduced motion so the looping mascot and skyline settle.
  tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(
    tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
  );
  tester.view.physicalSize = const Size(460, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(brightness: brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 200));
  }
  expect(tester.takeException(), isNull);
}

/// Registers one light and one dark smoke test for [build].
void _bothThemes(String name, Widget Function() build) {
  for (final brightness in Brightness.values) {
    testWidgets('$name renders in ${brightness.name} without exceptions', (
      tester,
    ) async {
      await _pumpInTheme(tester, build(), brightness);
    });
  }
}

String _themeName(Brightness brightness) => brightness.name;

void main() {
  _bothThemes('ns_background', () {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: NsBackground(child: const Center(child: Text('citizen'))),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 220,
          child: NsBackground(
            staff: true,
            child: const Center(child: Text('staff')),
          ),
        ),
      ],
    );
  });

  _bothThemes('ns_card', () {
    return const NsCard(child: Text('Card body'));
  });

  _bothThemes('ns_back_button', () => const NsBackButton());

  _bothThemes('ns_outline_button', () {
    return Column(
      children: [
        NsOutlineButton(label: 'Neutral', onPressed: () {}),
        const SizedBox(height: 12),
        NsOutlineButton(
          label: 'Green',
          onPressed: () {},
          tone: NsOutlineTone.green,
        ),
        const SizedBox(height: 12),
        NsOutlineButton(
          label: 'Danger',
          onPressed: () {},
          tone: NsOutlineTone.danger,
        ),
        const SizedBox(height: 12),
        const NsOutlineButton(label: 'Disabled', onPressed: null),
      ],
    );
  });

  _bothThemes('ns_google_button', () {
    return Column(
      children: [
        NsGoogleButton(onPressed: () {}),
        const SizedBox(height: 12),
        const NsGoogleButton(onPressed: null),
        const SizedBox(height: 18),
        const NsAuthDivider(),
      ],
    );
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'ns_google_button loading renders in ${_themeName(brightness)}',
      (tester) async {
        // The spinner animates forever, so settle is skipped on purpose.
        await _pumpInTheme(
          tester,
          const NsGoogleButton(onPressed: null, isLoading: true),
          brightness,
          settle: false,
        );
      },
    );
  }

  _bothThemes('ns_segmented_control', () {
    return NsSegmentedControl(
      segments: const ['Reports', 'Map', 'Profile'],
      selectedIndex: 1,
      onChanged: (_) {},
    );
  });

  _bothThemes('ns_auth_heading', () {
    return const NsAuthHeading(
      title: 'Create your account',
      message: 'Let us get you set up in a minute.',
    );
  });

  _bothThemes('ns_logo', () {
    return const Column(
      children: [
        NsBrand(),
        SizedBox(height: 16),
        NsLogo(size: 64, depth: 4),
      ],
    );
  });

  _bothThemes('ns_step_progress', () {
    return const Column(
      children: [
        NsStepProgress(step: 0, total: 3),
        SizedBox(height: 12),
        NsStepProgress(step: 2, total: 3),
      ],
    );
  });

  _bothThemes('ns_chip', () {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final tone in NsChipTone.values)
          NsChip(label: tone.name, tone: tone, icon: Icons.circle),
        for (final tone in NsChipTone.values)
          NsChip(label: tone.name, tone: tone, compact: true),
      ],
    );
  });

  _bothThemes('ns_city_art', () {
    return const NsCityArt(height: 160);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'ns_text_field renders with readable input in ${_themeName(brightness)}',
      (tester) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);

        await _pumpInTheme(
          tester,
          NsTextField(
            controller: controller,
            label: 'Email address',
            hint: 'you@example.com',
            icon: Icons.mail_rounded,
            helper: 'We only use this for ward notices.',
          ),
          brightness,
        );

        await tester.enterText(find.byType(TextFormField), 'citizen@nagarsathi.app');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final editable = tester.widget<EditableText>(find.byType(EditableText));
        final inputColor = editable.style.color!;
        final context = tester.element(find.byType(NsTextField));
        final fill = Theme.of(context).inputDecorationTheme.fillColor!;

        expect(
          _contrast(inputColor, fill),
          greaterThanOrEqualTo(4.5),
          reason:
              'Input text $inputColor on fill $fill in '
              '${_themeName(brightness)} mode must stay readable.',
        );
      },
    );
  }

  testWidgets('ns_text_field input uses the dark ink token in dark mode', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpInTheme(
      tester,
      NsTextField(
        controller: controller,
        label: 'Email address',
        hint: 'you@example.com',
      ),
      Brightness.dark,
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    final context = tester.element(find.byType(NsTextField));

    expect(editable.style.color, NsColors.dark.ink);
    expect(
      Theme.of(context).inputDecorationTheme.fillColor,
      NsColors.dark.surface,
    );
  });
}
