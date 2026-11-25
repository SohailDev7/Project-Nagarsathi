import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'screens/app_lock_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/staff_home_screen.dart';
import 'screens/admin/ward_officer_management_screen.dart';
import 'services/auth_service.dart';
import 'services/firebase_bootstrap.dart';
import 'services/session_service.dart';
import 'services/staff_auth_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_lock_gate.dart';
import 'widgets/update_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Authentication is disabled unless Firebase initializes successfully.
  await FirebaseBootstrap.initialize();
  // Guarded internally; falls back to ThemeMode.system if storage is
  // unavailable.
  await ThemeController.instance.load();

  // Honour "Remember me on this device" before the first frame. Firebase keeps
  // its session on disk; when the user opted out we clear it and start at
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
    await const SessionService().clearStaffSession();
  }
  final startSignedIn = hasSession && rememberMe;
  if (!startSignedIn) {
    // App Lock only protects an active remembered session.
    await const SessionService().saveAppLock(false);
  }
  final staffSession = startSignedIn
      ? await const SessionService().loadStaffSession()
      : null;
  // App Lock only matters when there is a remembered session to protect.
  final appLockEnabled =
      startSignedIn && await const SessionService().loadAppLock();

  runApp(
    NagarSathiApp(
      startSignedIn: startSignedIn,
      initialStaffSession: staffSession,
      appLockEnabled: appLockEnabled,
    ),
  );
}

class NagarSathiApp extends StatefulWidget {
  const NagarSathiApp({
    super.key,
    this.themeController,
    this.startSignedIn = false,
    this.initialStaffSession,
    this.appLockEnabled = false,
  });

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? themeController;

  /// Opens the citizen home when a remembered Firebase session already exists.
  final bool startSignedIn;

  /// Restores a remembered staff/admin workspace if present.
  final StaffSession? initialStaffSession;

  /// Whether the remembered session must pass the phone's biometric or screen
  /// lock check before it opens.
  final bool appLockEnabled;

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
          home: _buildHome(),
        );
      },
    );
  }

  Widget _buildHome() {
    final staffSession = widget.initialStaffSession;
    final hasRememberedSession = staffSession != null || widget.startSignedIn;

    final Widget signedInHome = staffSession != null
        ? StaffHomeScreen(
            staffIdentifier: staffSession.identifier,
            isPhone: staffSession.isPhone,
          )
        : const HomeScreen();

    if (!hasRememberedSession) {
      return LoginScreen(themeController: _themeController);
    }

    // The gate re-locks a running session after a spell in the background.
    final Widget gatedHome = AppLockGate(
      isStaff: staffSession != null,
      child: signedInHome,
    );

    if (!widget.appLockEnabled) return gatedHome;

    // Cold start: show the lock first, then hand over to the gated home.
    return AppLockScreen(
      isStaff: staffSession != null,
      target: (_) => gatedHome,
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
