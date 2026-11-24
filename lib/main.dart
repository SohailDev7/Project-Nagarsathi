import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/app_locale.dart';
import 'l10n/app_strings.dart';
import 'l10n/language_controller.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin/ward_officer_management_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/session_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Authentication is disabled unless Firebase initializes successfully.
  await FirebaseBootstrap.initialize();
  // Guarded internally; falls back to ThemeMode.system if storage is
  // unavailable.
  await ThemeController.instance.load();
  await LanguageController.instance.load();

  // Honour "Remember me on this device" before the first frame. Firebase keeps
  // its session on disk; when the citizen opted out we clear it and start at
  // the sign-in screen instead.
  final rememberMe = await const SessionService().loadRememberMe();
  User? sessionUser;
  if (AuthService.isConfigured) {
    try {
      sessionUser = FirebaseAuth.instance.currentUser;
    } catch (_) {
      // Auth plugin unavailable; treat it as signed out.
    }
  }
  final hasSession = sessionUser != null;
  if (hasSession && !rememberMe) {
    await const AuthService().signOut();
  }
  final startSignedIn = hasSession && rememberMe;

  runApp(NagarSathiApp(startSignedIn: startSignedIn));
}

class NagarSathiApp extends StatefulWidget {
  const NagarSathiApp({
    super.key,
    this.themeController,
    this.languageController,
    this.startSignedIn = false,
  });

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? themeController;
  final LanguageController? languageController;

  /// Opens the citizen home when a remembered Firebase session already exists.
  final bool startSignedIn;

  @override
  State<NagarSathiApp> createState() => _NagarSathiAppState();
}

class _NagarSathiAppState extends State<NagarSathiApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  ThemeController get _themeController =>
      widget.themeController ?? ThemeController.instance;

  LanguageController get _languageController =>
      widget.languageController ?? LanguageController.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController,
      builder: (context, mode, _) {
        return ValueListenableBuilder<AppLocale>(
          valueListenable: _languageController,
          builder: (context, locale, _) {
            final strings = AppStrings.forLocale(locale);
            return AppStringsScope(
              strings: strings,
              child: MaterialApp(
                title: strings.appName,
                debugShowCheckedModeBanner: false,
                navigatorKey: _navigatorKey,
                locale: locale.locale,
                supportedLocales: const [
                  Locale('en', 'US'),
                  Locale('ne', 'NP'),
                ],
                theme: buildAppTheme(brightness: Brightness.light),
                darkTheme: buildAppTheme(brightness: Brightness.dark),
                themeMode: mode,
                routes: {
                  WardOfficerManagementScreen.routeName: (_) =>
                      const WardOfficerManagementScreen(),
                },
                builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
                  value: _overlayStyle(context),
                  child: UpdateGate(
                    navigatorKey: _navigatorKey,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
                home: widget.startSignedIn
                    ? const HomeScreen()
                    : LoginScreen(
                        themeController: _themeController,
                        languageController: _languageController,
                      ),
              ),
            );
          },
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
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }
}
