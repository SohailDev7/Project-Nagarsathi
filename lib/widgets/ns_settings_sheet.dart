import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/app_locale.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_controller.dart';
import '../screens/settings_screen.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';
import 'ns_pressable.dart';
import 'ns_route.dart';

/// Opens the quick settings sheet used across the citizen, staff and admin
/// dashboards. Both appearance (dark mode) and language live here so the
/// dashboard headers stay uncluttered.
Future<void> showNsSettingsSheet(
  BuildContext context, {
  ThemeController? themeController,
  LanguageController? languageController,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => NsSettingsSheet(
      themeController: themeController,
      languageController: languageController,
    ),
  );
}

/// Round gear button that opens [NsSettingsSheet] from a dashboard top bar.
class NsSettingsButton extends StatelessWidget {
  const NsSettingsButton({
    super.key,
    this.onTap,
    this.themeController,
    this.languageController,
  });

  /// Overrides the default tap (which opens the settings sheet).
  final VoidCallback? onTap;
  final ThemeController? themeController;
  final LanguageController? languageController;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Semantics(
      button: true,
      label: context.l10n.openSettings,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('open-quick-settings'),
          onTap:
              onTap ??
              () {
                HapticFeedback.selectionClick();
                showNsSettingsSheet(
                  context,
                  themeController: themeController,
                  languageController: languageController,
                );
              },
          customBorder: const CircleBorder(),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tokens.surface,
              shape: BoxShape.circle,
              border: Border.all(color: tokens.border, width: 1.5),
            ),
            child: Icon(
              Icons.settings_rounded,
              size: 19,
              color: tokens.heading,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet with the theme and language switchers laid out like the
/// dashboard's dark-mode pill.
class NsSettingsSheet extends StatelessWidget {
  const NsSettingsSheet({
    super.key,
    this.themeController,
    this.languageController,
  });

  final ThemeController? themeController;
  final LanguageController? languageController;

  ThemeController get _theme => themeController ?? ThemeController.instance;
  LanguageController get _language =>
      languageController ?? LanguageController.instance;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: tokens.border, width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SafeArea(
        top: false,
        child: ValueListenableBuilder<AppLocale>(
          valueListenable: _language,
          builder: (context, locale, _) {
            final strings = AppStrings.forLocale(locale);
            return ValueListenableBuilder<ThemeMode>(
              valueListenable: _theme,
              builder: (context, mode, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: tokens.mint,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 21,
                            color: tokens.accentText,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.settings,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                  color: tokens.heading,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                strings.settingsSubtitle,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: tokens.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(strings.appearanceShort),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SettingsPill(
                            key: const Key('quick-theme-system'),
                            icon: Icons.brightness_auto_rounded,
                            label: strings.systemShort,
                            selected: mode == ThemeMode.system,
                            onTap: () => _theme.setMode(ThemeMode.system),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SettingsPill(
                            key: const Key('quick-theme-light'),
                            icon: Icons.light_mode_rounded,
                            label: strings.lightShort,
                            selected: mode == ThemeMode.light,
                            onTap: () => _theme.setMode(ThemeMode.light),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SettingsPill(
                            key: const Key('quick-theme-dark'),
                            icon: Icons.dark_mode_rounded,
                            label: strings.darkShort,
                            selected: mode == ThemeMode.dark,
                            onTap: () => _theme.setMode(ThemeMode.dark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel(strings.languageShort),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _SettingsPill(
                            key: const Key('quick-language-en'),
                            icon: Icons.language_rounded,
                            label: AppLocale.en.label,
                            selected: locale.isEnglish,
                            onTap: () => _language.setLocale(AppLocale.en),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SettingsPill(
                            key: const Key('quick-language-ne'),
                            icon: Icons.translate_rounded,
                            label: AppLocale.ne.label,
                            selected: locale.isNepali,
                            onTap: () => _language.setLocale(AppLocale.ne),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    NsPressable(
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          NsPageRoute<void>(
                            builder: (_) => SettingsScreen(
                              controller: _theme,
                              languageController: _language,
                            ),
                          ),
                        );
                      },
                      color: tokens.surfaceSoft,
                      borderColor: tokens.border,
                      shadowColor: tokens.shadow,
                      depth: 3,
                      radius: 16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 17,
                            color: tokens.accentText,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              strings.openSettings,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: tokens.ink,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: tokens.muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.9,
        color: NsColors.of(context).muted,
      ),
    );
  }
}

/// A chunky pill that mirrors the dashboard dark-mode switcher.
class _SettingsPill extends StatelessWidget {
  const _SettingsPill({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fill = selected ? tokens.mint : tokens.surfaceSoft;
    final border = selected ? AppColors.primary : tokens.border;
    final ink = selected ? tokens.accentText : tokens.muted;

    return NsPressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      color: fill,
      borderColor: border,
      shadowColor: selected
          ? (isDark ? Colors.black : AppColors.primaryDark)
          : (isDark ? Colors.black : tokens.shadow),
      depth: 2,
      radius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                color: ink,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
