import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectnagarsathi/models/app_update.dart';
import 'package:projectnagarsathi/screens/sign_up_screen.dart';
import 'package:projectnagarsathi/services/update_service.dart';
import 'package:projectnagarsathi/theme/app_theme.dart';
import 'package:projectnagarsathi/widgets/update_dialog.dart';

void main() {
  Future<void> prep(WidgetTester tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> shoot(WidgetTester tester, GlobalKey key, String name) async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '${Directory.systemTemp.path}\\$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  testWidgets('capture sign up wizard', (tester) async {
    await prep(tester);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(theme: buildAppTheme(), home: const SignUpScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await shoot(tester, key, 'wizard1');
  });

  testWidgets('capture update dialog', (tester) async {
    await prep(tester);

    final service = UpdateService();
    addTearDown(service.dispose);

    const update = AppUpdate(
      version: AppVersion(major: 1, minor: 1, patch: 0, build: 3),
      tag: 'v1.1.0',
      notes:
          'Brand new step-by-step sign up\n'
          'Faster, safer update downloads\n'
          'Fixed the keyboard covering the login button',
      apkUrl: 'https://example.com/app-release.apk',
      apkSize: 51337335,
      isPriority: false,
      releaseUrl: 'https://github.com/SohailDev7/Project-Nagarsathi/releases',
    );

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            backgroundColor: const Color(0xFF2F3A34),
            body: UpdateDialog(update: update, service: service),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, key, 'update-dialog');
  });
}
