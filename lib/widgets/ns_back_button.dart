import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Circular white back button with a hairline border.
class NsBackButton extends StatelessWidget {
  const NsBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        padding: EdgeInsets.zero,
        splashRadius: 22,
        tooltip: 'Back',
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
