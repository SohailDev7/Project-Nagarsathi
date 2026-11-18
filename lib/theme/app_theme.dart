import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

/// NagarSathi's playful civic palette.
///
/// Vivid lime is the action colour, forest is the ink, and cream keeps the
/// screen warm instead of clinical white.
abstract final class AppColors {
  static const primary = Color(0xFF58CC02);
  static const primaryDark = Color(0xFF3F9E00);
  static const primaryDeep = Color(0xFF2E7D0B);
  static const primaryLight = Color(0xFF89E219);

  static const forest = Color(0xFF163B2B);
  static const forestSoft = Color(0xFF24523C);

  static const background = Color(0xFFFFFDF5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFF7F8EE);

  static const border = Color(0xFFE3E7D9);
  static const borderStrong = Color(0xFFD3DAC4);
  static const ink = Color(0xFF1F3329);
  static const muted = Color(0xFF6B7D71);

  static const error = Color(0xFFE04B43);
  static const errorDark = Color(0xFFB2352F);

  static const sun = Color(0xFFFFC800);
  static const sky = Color(0xFF1CB0F6);
  static const mint = Color(0xFFE8F8D8);
  static const blush = Color(0xFFFFB199);
  static const shadow = Color(0xFFE7EBD9);
}

/// Chunky radii and hard bottom shadows used across the app.
abstract final class NsTokens {
  static const radius = 16.0;
  static const cardRadius = 24.0;
  static const buttonDepth = 4.0;
  static const cardDepth = 5.0;
  static const borderWidth = 2.0;
  static const maxContentWidth = 430.0;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.mint,
    onPrimaryContainer: AppColors.forest,
    secondary: AppColors.sun,
    onSecondary: AppColors.forest,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.borderStrong,
    error: AppColors.error,
  );

  const fieldRadius = BorderRadius.all(Radius.circular(NsTokens.radius));
  const fieldBorder = OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: AppColors.borderStrong, width: 2),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 44,
        height: 1.02,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.6,
        color: AppColors.forest,
      ),
      displayMedium: TextStyle(
        fontSize: 38,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.3,
        color: AppColors.forest,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        color: AppColors.forest,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.7,
        color: AppColors.forest,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: AppColors.forest,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: AppColors.forest,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.primaryDeep,
      selectionColor: AppColors.primary.withValues(alpha: 0.22),
      selectionHandleColor: AppColors.primaryDark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
      prefixIconColor: AppColors.primaryDeep,
      suffixIconColor: AppColors.muted,
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 24),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.primary, width: 2.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.error, width: 2),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.error, width: 2.4),
      ),
      errorStyle: const TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.errorDark,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryDeep,
        textStyle: const TextStyle(
          fontFamily: 'Nunito',
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
        ),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      side: const BorderSide(color: AppColors.borderStrong, width: 2),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.surface,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.border,
      circularTrackColor: AppColors.border,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.forest,
      contentTextStyle: const TextStyle(
        fontFamily: 'Nunito',
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
  );
}
