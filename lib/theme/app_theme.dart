import 'package:material_ui/material_ui.dart';

import '../widgets/ns_route.dart';

/// NagarSathi's playful civic palette.
///
/// Vivid lime is the action colour, forest is the ink, and a warm cream paper
/// backdrop keeps the screen bright without going clinical white. Sky, sun,
/// and coral add the secondary hues so the light theme reads as colourful
/// rather than green-on-green.
///
/// These are the frozen light-mode tokens kept for existing screens. New
/// code should read [NsColors] from the active theme instead.
abstract final class AppColors {
  static const primary = Color(0xFF58CC02);
  static const primaryDark = Color(0xFF3F9E00);
  static const primaryDeep = Color(0xFF2E7D0B);
  static const primaryLight = Color(0xFF89E219);

  static const forest = Color(0xFF163B2B);
  static const forestSoft = Color(0xFF24523C);

  static const background = Color(0xFFF8F0DE);
  static const surface = Color(0xFFFFFDF8);
  static const surfaceSoft = Color(0xFFF3EBD7);

  static const border = Color(0xFFCFD9B8);
  static const borderStrong = Color(0xFFBFCCA6);
  static const ink = Color(0xFF16281C);
  static const muted = Color(0xFF57685A);

  static const error = Color(0xFFE04B43);
  static const errorDark = Color(0xFF8C1D18);

  static const sun = Color(0xFFFFC800);
  static const sky = Color(0xFF1CB0F6);
  static const mint = Color(0xFFE9F7D2);
  static const blush = Color(0xFFFF8F70);
  static const shadow = Color(0xFFE6DCC2);
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

/// Theme-aware surface and ink tokens.
///
/// Existing screens still read the frozen [AppColors] values; new code (and
/// the dark-mode migration in PR 2) should read tokens from here so surfaces,
/// borders, and text follow the active [Brightness].
@immutable
class NsColors extends ThemeExtension<NsColors> {
  const NsColors({
    required this.background,
    required this.staffBackground,
    required this.surface,
    required this.surfaceSoft,
    required this.border,
    required this.hairline,
    required this.inputBorder,
    required this.controlBorder,
    required this.ink,
    required this.heading,
    required this.muted,
    required this.shadow,
    required this.accentText,
    required this.accentBright,
    required this.primaryStrong,
    required this.errorBorder,
    required this.mint,
  });

  final Color background;

  /// Staff portal backdrop; a touch greener than [background].
  final Color staffBackground;

  final Color surface;
  final Color surfaceSoft;

  /// Decorative borders: cards, bubbles, dividers.
  final Color border;

  /// Hairline rules such as tab rails and disabled edges.
  final Color hairline;

  /// Text-field boundary.
  final Color inputBorder;

  /// Boundary for buttons and other interactive controls. Matches [border] in
  /// light and [inputBorder] in dark so controls stay visible on dark surfaces.
  final Color controlBorder;

  /// Body ink.
  final Color ink;

  /// Display ink for titles, labels, and brand wordmark.
  final Color heading;

  final Color muted;
  final Color shadow;
  final Color accentText;

  /// Bright lime accent used for glows, logo art, and gradients.
  final Color accentBright;

  /// Deep lime used for the primary button's edge and green outlines.
  final Color primaryStrong;

  /// Error outline, which stays brighter than error text.
  final Color errorBorder;

  final Color mint;

  static const light = NsColors(
    background: Color(0xFFF8F0DE),
    staffBackground: Color(0xFFEEF6E2),
    surface: Color(0xFFFFFDF8),
    surfaceSoft: Color(0xFFF3EBD7),
    border: Color(0xFFCFD9B8),
    hairline: Color(0xFFE5DDC7),
    inputBorder: Color(0xFF9FB383),
    controlBorder: Color(0xFFBFCCA6),
    ink: Color(0xFF16281C),
    heading: Color(0xFF0A1F12),
    muted: Color(0xFF57685A),
    shadow: Color(0xFFE6DCC2),
    accentText: Color(0xFF2F7A12),
    accentBright: Color(0xFF89E219),
    primaryStrong: Color(0xFF2D7A00),
    errorBorder: Color(0xFFC0392B),
    mint: Color(0xFFE9F7D2),
  );

  static const dark = NsColors(
    // Emerald night: a saturated pine backdrop, clearly green rather than
    // near-black, with progressively lighter card layers so surfaces separate.
    background: Color(0xFF072A1C),
    staffBackground: Color(0xFF041F14),
    surface: Color(0xFF0E3B27),
    surfaceSoft: Color(0xFF164C33),
    border: Color(0xFF2F7351),
    hairline: Color(0xFF215B3C),
    inputBorder: Color(0xFF7DBB9C),
    controlBorder: Color(0xFF7DBB9C),
    ink: Color(0xFFEAFBF0),
    heading: Color(0xFFF6FFF9),
    muted: Color(0xFFA6CDB7),
    shadow: Color(0xFF02140C),
    accentText: Color(0xFFB0FF5E),
    accentBright: Color(0xFFC0FF72),
    primaryStrong: Color(0xFF57C900),
    errorBorder: Color(0xFFFFB4AB),
    mint: Color(0xFF11462C),
  );

  /// The tokens for the nearest enclosing theme, falling back to light.
  static NsColors of(BuildContext context) {
    return Theme.of(context).extension<NsColors>() ?? light;
  }

  @override
  NsColors copyWith({
    Color? background,
    Color? staffBackground,
    Color? surface,
    Color? surfaceSoft,
    Color? border,
    Color? hairline,
    Color? inputBorder,
    Color? controlBorder,
    Color? ink,
    Color? heading,
    Color? muted,
    Color? shadow,
    Color? accentText,
    Color? accentBright,
    Color? primaryStrong,
    Color? errorBorder,
    Color? mint,
  }) {
    return NsColors(
      background: background ?? this.background,
      staffBackground: staffBackground ?? this.staffBackground,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      border: border ?? this.border,
      hairline: hairline ?? this.hairline,
      inputBorder: inputBorder ?? this.inputBorder,
      controlBorder: controlBorder ?? this.controlBorder,
      ink: ink ?? this.ink,
      heading: heading ?? this.heading,
      muted: muted ?? this.muted,
      shadow: shadow ?? this.shadow,
      accentText: accentText ?? this.accentText,
      accentBright: accentBright ?? this.accentBright,
      primaryStrong: primaryStrong ?? this.primaryStrong,
      errorBorder: errorBorder ?? this.errorBorder,
      mint: mint ?? this.mint,
    );
  }

  @override
  NsColors lerp(covariant NsColors? other, double t) {
    if (other == null) return this;
    return NsColors(
      background: Color.lerp(background, other.background, t)!,
      staffBackground: Color.lerp(
        staffBackground,
        other.staffBackground,
        t,
      )!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      border: Color.lerp(border, other.border, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      heading: Color.lerp(heading, other.heading, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      accentText: Color.lerp(accentText, other.accentText, t)!,
      accentBright: Color.lerp(accentBright, other.accentBright, t)!,
      primaryStrong: Color.lerp(primaryStrong, other.primaryStrong, t)!,
      errorBorder: Color.lerp(errorBorder, other.errorBorder, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
    );
  }
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final tokens = isDark ? NsColors.dark : NsColors.light;

  final heading = tokens.heading;
  final errorBorder = isDark ? tokens.errorBorder : AppColors.error;
  final errorText = isDark ? tokens.errorBorder : AppColors.errorDark;

  final scheme = isDark
      ? ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: AppColors.forest,
          primaryContainer: tokens.mint,
          onPrimaryContainer: tokens.accentBright,
          secondary: AppColors.sun,
          onSecondary: AppColors.forest,
          secondaryContainer: const Color(0xFF453809),
          onSecondaryContainer: const Color(0xFFFFD24A),
          tertiary: AppColors.sky,
          onTertiary: const Color(0xFF04202B),
          tertiaryContainer: const Color(0xFF0E3D53),
          onTertiaryContainer: const Color(0xFF9FE1FF),
          surface: tokens.surface,
          onSurface: tokens.ink,
          surfaceContainerLowest: tokens.background,
          surfaceContainerLow: tokens.surface,
          surfaceContainer: tokens.surface,
          surfaceContainerHigh: tokens.surfaceSoft,
          surfaceContainerHighest: tokens.surfaceSoft,
          onSurfaceVariant: tokens.muted,
          outline: tokens.border,
          outlineVariant: tokens.inputBorder,
          error: tokens.errorBorder,
          onError: const Color(0xFF690005),
          shadow: tokens.shadow,
          scrim: const Color(0xFF000000),
          inverseSurface: tokens.ink,
          onInverseSurface: tokens.background,
          inversePrimary: tokens.accentBright,
        )
      : ColorScheme.light(
          primary: AppColors.primary,
          onPrimary: AppColors.forest,
          primaryContainer: tokens.mint,
          onPrimaryContainer: AppColors.forest,
          secondary: AppColors.sun,
          onSecondary: AppColors.forest,
          surface: tokens.surface,
          onSurface: tokens.ink,
          onSurfaceVariant: tokens.muted,
          outline: tokens.border,
          outlineVariant: tokens.inputBorder,
          error: AppColors.errorDark,
          onError: Colors.white,
          shadow: tokens.shadow,
          scrim: const Color(0xFF000000),
          inverseSurface: AppColors.forest,
          onInverseSurface: Colors.white,
          inversePrimary: AppColors.primaryLight,
        );

  const fieldRadius = BorderRadius.all(Radius.circular(NsTokens.radius));
  final fieldBorder = OutlineInputBorder(
    borderRadius: fieldRadius,
    borderSide: BorderSide(color: tokens.inputBorder, width: 2),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Nunito',
    fontFamilyFallback: const ['NotoSansDevanagari', 'sans-serif'],
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.surface,
    cardColor: tokens.surface,
    dividerColor: tokens.border,
    shadowColor: tokens.shadow,
    extensions: [tokens],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: NsSharedAxisPageTransitionsBuilder(),
        TargetPlatform.iOS: NsSharedAxisPageTransitionsBuilder(),
        TargetPlatform.macOS: NsSharedAxisPageTransitionsBuilder(),
        TargetPlatform.windows: NsSharedAxisPageTransitionsBuilder(),
        TargetPlatform.linux: NsSharedAxisPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.surface,
      foregroundColor: tokens.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 44,
        height: 1.02,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.6,
        color: heading,
      ),
      displayMedium: TextStyle(
        fontSize: 38,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.3,
        color: heading,
      ),
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.1,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        color: heading,
      ),
      headlineMedium: TextStyle(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.7,
        color: heading,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.2,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: heading,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: heading,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: tokens.muted,
      ),
      bodyMedium: TextStyle(
        fontSize: 14.5,
        height: 1.5,
        fontWeight: FontWeight.w600,
        color: tokens.muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.accentText,
      selectionColor: tokens.accentBright.withValues(
        alpha: isDark ? 0.30 : 0.24,
      ),
      selectionHandleColor: tokens.accentText,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: tokens.muted,
      ),
      helperStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: tokens.muted,
      ),
      prefixIconColor: tokens.accentText,
      suffixIconColor: tokens.muted,
      prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: 24),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      disabledBorder: fieldBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: const BorderSide(color: AppColors.primary, width: 2.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: errorBorder, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: errorBorder, width: 2.4),
      ),
      errorStyle: TextStyle(
        fontSize: 13,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: errorText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: tokens.accentText,
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
      side: BorderSide(color: tokens.border, width: 2),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : tokens.surface,
      ),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: tokens.border,
      circularTrackColor: tokens.border,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? tokens.ink : AppColors.forest,
      contentTextStyle: TextStyle(
        fontFamily: 'Nunito',
        color: isDark ? tokens.background : Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.surface,
      modalBackgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
  );
}
