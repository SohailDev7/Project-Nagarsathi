import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/admin/ward_officer_management_screen.dart';
import 'screens/login_screen.dart';
import 'services/firebase_bootstrap.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never blocks start-up: without Firebase config the app runs in offline
  // demo mode and the auth screens still work.
  await FirebaseBootstrap.initialize();
  // Guarded internally; falls back to ThemeMode.system if storage is
  // unavailable.
  await ThemeController.instance.load();
  runApp(const NagarSathiApp());
}

class NagarSathiApp extends StatefulWidget {
  const NagarSathiApp({super.key, this.themeController});

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? themeController;

  @override
  State<NagarSathiApp> createState() => _NagarSathiAppState();
}

class _NagarSathiAppState extends State<NagarSathiApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  ThemeController get _themeController =>
      widget.themeController ?? ThemeController.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'NagarSathi',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigatorKey,
          theme: buildAppTheme(brightness: Brightness.light),
          darkTheme: buildAppTheme(brightness: Brightness.dark),
          themeMode: mode,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
            value: _overlayStyle(context),
            child: UpdateGate(
              navigatorKey: _navigatorKey,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const LoginScreen(),
        );
      },
    );
  }

  SystemUiOverlayStyle _overlayStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barColor = NsColors.of(context).background;

    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      // iOS reads the status-bar *background* brightness.
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: barColor,
      systemNavigationBarDividerColor: barColor,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
    );
  }
}
