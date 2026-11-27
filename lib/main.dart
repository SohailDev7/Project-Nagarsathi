import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'l10n/app_locale.dart';
import 'l10n/app_strings.dart';
import 'l10n/language_controller.dart';
import 'screens/app_lock_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/staff_home_screen.dart';
import 'screens/superadmin_home_screen.dart';
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
  // Initialize Firebase and load local preferences in parallel to reduce cold-start delay.
  await Future.wait([
    FirebaseBootstrap.initialize(),
    ThemeController.instance.load(),
    LanguageController.instance.load(),
  ]);

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
    await Future.wait([
      const AuthService().signOut(),
      const SessionService().clearStaffSession(),
    ]);
  }
  final startSignedIn = hasSession && rememberMe;
  StaffSession? staffSession;
  var appLockEnabled = false;
  if (!startSignedIn) {
    // App Lock only protects an active remembered session.
    await const SessionService().saveAppLock(false);
  } else {
    final results = await Future.wait<Object?>([
      const SessionService().loadStaffSession(),
      const SessionService().loadAppLock(),
    ]);
    staffSession = results[0] as StaffSession?;
    appLockEnabled = (results[1] as bool?) ?? false;

    // The remembered session can belong to a different account than the one
    // currently signed in — a super admin signs out and a ward officer signs in
    // without "Remember device" — and its stored role is then stale. Always
    // rebuild the role from the live Firebase account plus its Firestore record
    // so a leftover flag cannot open the wrong console.
    if (staffSession != null) {
      String? liveEmail;
      String? livePhone;
      try {
        final liveUser = FirebaseAuth.instance.currentUser;
        liveEmail = liveUser?.email?.trim().toLowerCase();
        livePhone = liveUser?.phoneNumber?.trim();
      } catch (_) {
        // Auth plugin unavailable; keep the remembered identifier.
      }
      final hasLiveEmail = liveEmail != null && liveEmail.isNotEmpty;
      final hasLivePhone = livePhone != null && livePhone.isNotEmpty;
      final identifier = hasLiveEmail
          ? liveEmail
          : (hasLivePhone && staffSession.isPhone)
          ? livePhone
          : staffSession.identifier;
      final isPhone = !hasLiveEmail && staffSession.isPhone;
      await StaffAuthService.loadSuperAdminEmails();
      final isSuperAdmin =
          StaffAuthService.isSuperAdminEmail(liveEmail) ||
          StaffAuthService.isSuperAdminEmail(identifier) ||
          await const StaffAuthService().hasSuperAdminRecord();
      if (identifier != staffSession.identifier ||
          isPhone != staffSession.isPhone ||
          isSuperAdmin != staffSession.isSuperAdmin) {
        staffSession = StaffSession(
          identifier: identifier,
          isPhone: isPhone,
          mustChangePassword: staffSession.mustChangePassword,
          isSuperAdmin: isSuperAdmin,
        );
        await const SessionService().saveStaffSession(
          identifier: identifier,
          isPhone: isPhone,
          isSuperAdmin: isSuperAdmin,
        );
      }
    }
  }

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
    this.languageController,
    this.startSignedIn = false,
    this.initialStaffSession,
    this.appLockEnabled = false,
  });

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? themeController;
  final LanguageController? languageController;

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

  /// Built once: the start screen depends only on the arguments this widget was
  /// created with. Recomputing it on every theme or language rebuild made the
  /// Navigator swap its route child mid-transition, which reparents GlobalKeys
  /// ("Duplicate GlobalKey detected in widget tree").
  late final Widget _home = _buildHome();

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
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                theme: buildAppTheme(brightness: Brightness.light),
                darkTheme: buildAppTheme(brightness: Brightness.dark),
                themeMode: mode,
                themeAnimationDuration: const Duration(milliseconds: 260),
                themeAnimationCurve: Curves.easeOutCubic,
                routes: {
                  WardOfficerManagementScreen.routeName: (_) =>
                      const WardOfficerManagementScreen(),
                },
                builder: (context, child) =>
                    AnnotatedRegion<SystemUiOverlayStyle>(
                      value: _overlayStyle(context),
                      child: UpdateGate(
                        navigatorKey: _navigatorKey,
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                home: _home,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHome() {
    final staffSession = widget.initialStaffSession;
    final hasRememberedSession = staffSession != null || widget.startSignedIn;

    final Widget signedInHome = staffSession == null
        ? const HomeScreen()
        : staffSession.isSuperAdmin
        ? SuperAdminHomeScreen(staffIdentifier: staffSession.identifier)
        : StaffHomeScreen(
            staffIdentifier: staffSession.identifier,
            isPhone: staffSession.isPhone,
          );

    if (!hasRememberedSession) {
      return LoginScreen(
        themeController: _themeController,
        languageController: _languageController,
      );
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
