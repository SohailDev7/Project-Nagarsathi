import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum NsBentoTone { green, sun, sky, forest }

/// Compact bento cell used to fill the lower area of auth screens with useful,
/// scannable context instead of empty space.
class NsBentoTile extends StatelessWidget {
  const NsBentoTile({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
    this.tone = NsBentoTone.green,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final NsBentoTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border) = switch (tone) {
      NsBentoTone.green => (
        AppColors.mint,
        AppColors.primaryDeep,
        AppColors.primary.withValues(alpha: 0.34),
      ),
      NsBentoTone.sun => (
        AppColors.sun.withValues(alpha: 0.2),
        const Color(0xFF866400),
        AppColors.sun,
      ),
      NsBentoTone.sky => (
        AppColors.sky.withValues(alpha: 0.14),
        const Color(0xFF0B6C9E),
        AppColors.sky.withValues(alpha: 0.4),
      ),
      NsBentoTone.forest => (
        AppColors.primary.withValues(alpha: 0.18),
        AppColors.primaryLight,
        AppColors.primary.withValues(alpha: 0.45),
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderStrong, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            offset: const Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border, width: 1.2),
            ),
            child: Icon(icon, size: 17, color: foreground),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.15,
              fontWeight: FontWeight.w900,
              color: AppColors.forest,
              letterSpacing: -0.1,
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(
              caption!,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
