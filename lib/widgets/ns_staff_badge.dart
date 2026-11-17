import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_pressable.dart';

/// Always-visible top-bar entry point into the staff portal.
class NsStaffPortalLink extends StatelessWidget {
  const NsStaffPortalLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NsPressable(
      onTap: onTap,
      color: AppColors.forest,
      borderColor: AppColors.forestSoft,
      shadowColor: const Color(0xFF0C241A),
      depth: 3,
      radius: 999,
      expand: false,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      semanticLabel: 'Staff portal',
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_rounded, size: 14, color: AppColors.primaryLight),
          SizedBox(width: 6),
          Text(
            'Staff portal',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Identifies the staff area without changing the shared app branding.
class NsStaffBadge extends StatelessWidget {
  const NsStaffBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.18),
            offset: const Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.badge_rounded,
            size: compact ? 13 : 15,
            color: AppColors.primaryLight,
          ),
          const SizedBox(width: 6),
          Text(
            'STAFF PORTAL',
            style: TextStyle(
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
