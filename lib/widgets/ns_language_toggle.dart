import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_locale.dart';
import '../l10n/language_controller.dart';
import '../theme/app_theme.dart';
import 'ns_pressable.dart';

/// Tactile, one-tap global language switch (Nepali / English) for top headers.
///
/// Styled like the dark-mode switcher: a single chunky pill with an icon and
/// the current language name. Tapping flips to the other language.
class NsLanguageToggle extends StatelessWidget {
  const NsLanguageToggle({
    super.key,
    this.controller,
    this.compact = false,
  });

  /// Optional injected controller for testing. Defaults to [LanguageController.instance].
  final LanguageController? controller;

  /// Slightly tighter padding for constrained headers.
  final bool compact;

  LanguageController get _controller =>
      controller ?? LanguageController.instance;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLocale>(
      valueListenable: _controller,
      builder: (context, locale, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isNepali = locale.isNepali;

        return NsPressable(
          key: const Key('global-language-toggle'),
          onTap: () {
            HapticFeedback.selectionClick();
            _controller.toggle();
          },
          color: isDark ? const Color(0xFF243B30) : AppColors.mint,
          borderColor: isDark ? const Color(0xFF325444) : AppColors.primary,
          shadowColor: isDark ? const Color(0xFF0F1A14) : AppColors.primaryDark,
          depth: 2,
          radius: 999,
          expand: false,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 9 : 11,
            vertical: compact ? 6 : 7,
          ),
          semanticLabel: isNepali
              ? 'Switch language to English'
              : 'नेपाली भाषामा बदल्नुहोस्',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNepali ? Icons.translate_rounded : Icons.language_rounded,
                size: compact ? 13 : 15,
                color: isDark ? AppColors.sun : AppColors.forest,
              ),
              const SizedBox(width: 5),
              Text(
                locale.label,
                style: TextStyle(
                  fontSize: compact ? 11 : 11.5,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.forest,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
