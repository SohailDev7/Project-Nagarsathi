import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum NsChipTone { green, sun, sky, forest, muted }

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
    final (background, foreground, border) = switch (tone) {
      NsChipTone.green => (
        AppColors.mint,
        AppColors.primaryDeep,
        AppColors.primary.withValues(alpha: 0.34),
      ),
      NsChipTone.sun => (
        AppColors.sun.withValues(alpha: 0.2),
        const Color(0xFF866400),
        AppColors.sun,
      ),
      NsChipTone.sky => (
        AppColors.sky.withValues(alpha: 0.14),
        const Color(0xFF0B6C9E),
        AppColors.sky.withValues(alpha: 0.4),
      ),
      NsChipTone.forest => (AppColors.forest, Colors.white, AppColors.forest),
      NsChipTone.muted => (
        AppColors.surfaceSoft,
        AppColors.muted,
        AppColors.border,
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
