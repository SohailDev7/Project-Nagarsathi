import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Identifies the staff area without changing the shared app branding.
class NsStaffBadge extends StatelessWidget {
  const NsStaffBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 17, color: AppColors.primaryDark),
          SizedBox(width: 6),
          Text(
            'Staff portal',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
