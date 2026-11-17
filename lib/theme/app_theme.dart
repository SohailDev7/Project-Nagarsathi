import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

/// Minimal green palette for NagarSathi.
abstract final class AppColors {
  static const primary = Color(0xFF14724A);
  static const primaryDark = Color(0xFF0B4A31);
  static const primaryLight = Color(0xFF3E9B72);
  static const background = Color(0xFFF7F8F7);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E8E6);
  static const ink = Color(0xFF141A16);
  static const muted = Color(0xFF6C7671);
  static const error = Color(0xFFC2413A);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.background,
    onPrimaryContainer: AppColors.primaryDark,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    outline: AppColors.border,
    error: AppColors.error,
  );

  const fieldRadius = BorderRadius.all(Radius.circular(14));
  const fieldBorder = OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: AppColors.border),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      },
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.primary,
      selectionColor: AppColors.primary.withValues(alpha: 0.16),
      selectionHandleColor: AppColors.primary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      hintStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.muted,
      ),
      prefixIconColor: AppColors.muted,
      suffixIconColor: AppColors.muted,
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 24),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: AppColors.error, width: 1.4),
      ),
      errorStyle: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: AppColors.error,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        splashFactory: NoSplash.splashFactory,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      side: const BorderSide(color: AppColors.border, width: 1.4),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.border,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  );
}
