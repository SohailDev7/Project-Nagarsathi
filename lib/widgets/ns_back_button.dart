import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_pressable.dart';

/// Round chunky back affordance with the shared press physics.
class NsBackButton extends StatelessWidget {
  const NsBackButton({
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_back_rounded,
  });

  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return NsPressable(
      onTap: onPressed ?? () => Navigator.of(context).maybePop(),
      color: AppColors.surface,
      borderColor: AppColors.borderStrong,
      shadowColor: AppColors.shadow,
      depth: 3,
      radius: 14,
      expand: false,
      semanticLabel: 'Back',
      padding: const EdgeInsets.all(2),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Tooltip(
          message: 'Back',
          child: Center(child: Icon(icon, size: 22, color: AppColors.forest)),
        ),
      ),
    );
  }
}
