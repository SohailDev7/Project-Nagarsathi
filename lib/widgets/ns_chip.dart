import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum NsChipTone { green, sun, sky, forest, muted }

/// Status tints are deliberately fixed brand colours rather than surface
/// tokens: they keep their meaning in both themes.
abstract final class _ChipPalette {
  static const forest = Color(0xFF163B2B);
  static const sky = Color(0xFF1CB0F6);
  static const sunText = Color(0xFF4F3600);
  static const skyText = Color(0xFF033B5E);

  static const greenDark = Color(0xFF24523C);
  static const sunDark = Color(0xFF453809);
  static const sunTextDark = Color(0xFFFFD24A);
  static const skyDark = Color(0xFF14405A);
  static const skyTextDark = Color(0xFF6FD0FA);
}

/// Small, extra-bold pill used for status and context labels.
class NsChip extends StatelessWidget {
  const NsChip({
    super.key,
    required this.label,
    this.icon,
    this.tone = NsChipTone.green,
    this.compact = false,
  });

  final String label;
  final IconData? icon;
  final NsChipTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (background, foreground, border) = isDark
        ? switch (tone) {
            NsChipTone.green => (
              _ChipPalette.greenDark,
              tokens.accentText,
              scheme.primary.withValues(alpha: 0.45),
            ),
            NsChipTone.sun => (
              _ChipPalette.sunDark,
              _ChipPalette.sunTextDark,
              scheme.secondary.withValues(alpha: 0.5),
            ),
            NsChipTone.sky => (
              _ChipPalette.skyDark,
              _ChipPalette.skyTextDark,
              _ChipPalette.sky.withValues(alpha: 0.5),
            ),
            NsChipTone.forest => (
              _ChipPalette.forest,
              Colors.white,
              scheme.primary.withValues(alpha: 0.25),
            ),
            NsChipTone.muted => (
              tokens.surfaceSoft,
              tokens.muted,
              tokens.border,
            ),
          }
        : switch (tone) {
            NsChipTone.green => (
              tokens.mint,
              tokens.accentText,
              scheme.primary.withValues(alpha: 0.34),
            ),
            NsChipTone.sun => (
              const Color(0xFFF2D46B),
              _ChipPalette.sunText,
              scheme.secondary,
            ),
            NsChipTone.sky => (
              const Color(0xFF9FD9F7),
              _ChipPalette.skyText,
              _ChipPalette.sky.withValues(alpha: 0.6),
            ),
            NsChipTone.forest => (
              _ChipPalette.forest,
              Colors.white,
              _ChipPalette.forest,
            ),
            NsChipTone.muted => (
              tokens.surfaceSoft,
              tokens.muted,
              tokens.hairline,
            ),
          };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 12 : 14, color: foreground),
            SizedBox(width: compact ? 3 : 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w900,
              color: foreground,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}
