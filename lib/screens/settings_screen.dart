import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

/// Theme preference screen: System, Light, or Dark.
///
/// This screen is intentionally theme-aware from day one (it reads
/// [NsColors]); the rest of the app follows in PR 2.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.controller});

  /// Injectable for tests; defaults to the app-wide controller.
  final ThemeController? controller;

  ThemeController get _controller => controller ?? ThemeController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        top: false,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _controller,
          builder: (context, mode, _) {
            final tokens = NsColors.of(context);
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              children: [
                Text(
                  'Theme',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                    color: tokens.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how NagarSathi looks. System follows your device '
                  'setting automatically.',
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
                  ),
                ),
                const SizedBox(height: 18),
                for (final option in _options) ...[
                  _ThemeOption(
                    mode: option.mode,
                    icon: option.icon,
                    title: option.title,
                    subtitle: option.subtitle,
                    selected: mode == option.mode,
                    onTap: () => _controller.setMode(option.mode),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                const _ThemePreview(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ThemeOptionData {
  const _ThemeOptionData({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
}

const _options = <_ThemeOptionData>[
  _ThemeOptionData(
    mode: ThemeMode.system,
    icon: Icons.brightness_auto_rounded,
    title: 'System',
    subtitle: 'Match your device setting',
  ),
  _ThemeOptionData(
    mode: ThemeMode.light,
    icon: Icons.light_mode_rounded,
    title: 'Light',
    subtitle: 'Warm cream background',
  ),
  _ThemeOptionData(
    mode: ThemeMode.dark,
    icon: Icons.dark_mode_rounded,
    title: 'Dark',
    subtitle: 'Easier on the eyes at night',
  ),
];

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('theme-mode-${mode.name}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? scheme.primary : tokens.border,
                width: selected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? tokens.mint : tokens.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected ? tokens.accentText : tokens.muted,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: tokens.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 22,
                  color: selected ? scheme.primary : tokens.inputBorder,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small live sample so the effect is visible without leaving the screen.
class _ThemePreview extends StatelessWidget {
  const _ThemePreview();

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      key: const Key('theme-preview'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tokens.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PREVIEW',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
              color: tokens.muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: tokens.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 18,
                  color: tokens.accentText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Ward 16 · Kathmandu',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: tokens.ink,
                    ),
                  ),
                ),
                Text(
                  'Muted',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Primary action',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: tokens.mint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: tokens.border),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: tokens.accentText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
