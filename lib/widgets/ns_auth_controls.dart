import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_controller.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'ns_auth_heading.dart';

/// Minimal ghost pill pair (`EN`/`ने` | Light/Dark icon) blended into headers.
class NsAuthPreferencePills extends StatelessWidget {
  const NsAuthPreferencePills({
    super.key,
    this.themeController,
    this.languageController,
    this.heroTag,
    this.onDarkHeader = false,
  });

  final ThemeController? themeController;
  final LanguageController? languageController;
  final String? heroTag;

  /// True when placed over a dark command header (e.g. Staff Login).
  final bool onDarkHeader;

  ThemeController get _theme => themeController ?? ThemeController.instance;
  LanguageController get _language =>
      languageController ?? LanguageController.instance;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = context.l10n;
    final darkChrome = onDarkHeader || isDark;

    final bgColor = onDarkHeader
        ? (isDark
              ? const Color(0xFF081610).withValues(alpha: 0.78)
              : const Color(0xFF0C4225).withValues(alpha: 0.78))
        : (isDark
              ? Colors.white.withValues(alpha: 0.11)
              : tokens.surfaceSoft.withValues(alpha: 0.9));
    final borderColor = darkChrome
        ? Colors.white.withValues(alpha: 0.22)
        : tokens.border;
    final dividerColor = darkChrome
        ? Colors.white.withValues(alpha: 0.22)
        : tokens.hairline;
    final labelColor = darkChrome ? Colors.white : tokens.heading;
    final iconColor = darkChrome ? AppColors.primaryLight : tokens.accentText;

    final content = Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<AppLocale>(
            valueListenable: _language,
            builder: (context, locale, _) {
              final isNepali = locale.isNepali;
              return _PillToggleChip(
                key: const Key('global-language-toggle'),
                tooltip: isNepali
                    ? 'Switch language to English'
                    : 'नेपाली भाषामा बदल्नुहोस्',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _language.toggle();
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: Row(
                    key: ValueKey(locale.code),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isNepali
                            ? Icons.translate_rounded
                            : Icons.language_rounded,
                        size: 13.5,
                        color: iconColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isNepali ? 'ने' : 'EN',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: labelColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Container(
            width: 1,
            height: 15,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: dividerColor,
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: _theme,
            builder: (context, mode, _) {
              return _PillToggleChip(
                key: const Key('global-theme-toggle'),
                tooltip: isDark
                    ? strings.switchToLightMode
                    : strings.switchToDarkMode,
                onTap: () {
                  HapticFeedback.selectionClick();
                  _theme.setMode(isDark ? ThemeMode.light : ThemeMode.dark);
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey(isDark),
                    size: 15.5,
                    color: isDark
                        ? AppColors.sun
                        : (onDarkHeader ? Colors.white : tokens.heading),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );

    if (heroTag == null) return content;
    return Hero(
      tag: heroTag!,
      flightShuttleBuilder: nsHeroShuttle,
      child: content,
    );
  }
}

class _PillToggleChip extends StatelessWidget {
  const _PillToggleChip({
    super.key,
    required this.tooltip,
    required this.onTap,
    required this.child,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sleek soft-tinted Google | Facebook social sign-in pills.
class NsSocialAuthRow extends StatelessWidget {
  const NsSocialAuthRow({
    super.key,
    required this.onGooglePressed,
    this.onFacebookPressed,
    this.googleLoading = false,
    this.facebookLoading = false,
  });

  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;
  final bool googleLoading;
  final bool facebookLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = googleLoading || facebookLoading;

    final fbTint = isDark ? const Color(0xFF172941) : const Color(0xFF9BC3FF);
    final fbBorder = isDark
        ? const Color(0xFF28466E)
        : const Color(0xFF5D96ED);
    final fbInk = isDark ? const Color(0xFF84B8FF) : const Color(0xFF0A357A);

    return Row(
      children: [
        Expanded(
          child: _SoftSocialPill(
            key: const Key('social-google-pill'),
            semanticLabel: context.l10n.continueWithGoogle,
            fillColor: isDark ? tokens.surface : tokens.surfaceSoft,
            borderColor: tokens.border,
            isLoading: googleLoading,
            loaderColor: tokens.accentText,
            onTap: busy ? null : onGooglePressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon/google_g.png',
                  width: 18,
                  height: 18,
                  filterQuality: FilterQuality.high,
                ),
                const SizedBox(width: 8),
                Text(
                  'Google',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tokens.heading,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (onFacebookPressed != null) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _SoftSocialPill(
              key: const Key('social-facebook-pill'),
              semanticLabel: context.l10n.continueWithFacebook,
              fillColor: fbTint,
              borderColor: fbBorder,
              isLoading: facebookLoading,
              loaderColor: fbInk,
              onTap: busy ? null : onFacebookPressed,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.facebook_rounded, size: 20, color: fbInk),
                  const SizedBox(width: 8),
                  Text(
                    'Facebook',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: fbInk,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SoftSocialPill extends StatefulWidget {
  const _SoftSocialPill({
    super.key,
    required this.semanticLabel,
    required this.fillColor,
    required this.borderColor,
    required this.isLoading,
    required this.loaderColor,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final Color fillColor;
  final Color borderColor;
  final bool isLoading;
  final Color loaderColor;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_SoftSocialPill> createState() => _SoftSocialPillState();
}

class _SoftSocialPillState extends State<_SoftSocialPill> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.isLoading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled
            ? (_) {
                HapticFeedback.selectionClick();
                setState(() => _pressed = true);
              }
            : null,
        onTapUp: (_) {
          if (_pressed) setState(() => _pressed = false);
        },
        onTapCancel: () {
          if (_pressed) setState(() => _pressed = false);
        },
        onTap: enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: _pressed && enabled ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: widget.fillColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: widget.borderColor, width: 1.2),
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: widget.isLoading
                    ? SizedBox(
                        key: const ValueKey('loader'),
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.loaderColor,
                          ),
                        ),
                      )
                    : FittedBox(
                        key: const ValueKey('label'),
                        fit: BoxFit.scaleDown,
                        child: widget.child,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
