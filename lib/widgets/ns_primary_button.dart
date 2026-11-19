import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_pressable.dart';

/// Extra-chunky primary action with a built-in loading state.
class NsPrimaryButton extends StatelessWidget {
  const NsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 54,
    this.color = AppColors.primary,
    this.shadowColor = AppColors.primaryDark,
    this.borderColor = AppColors.primaryDark,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final Color color;
  final Color shadowColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final canTap = !isLoading && onPressed != null;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return NsPressable(
      onTap: canTap ? onPressed : null,
      color: canTap ? color : AppColors.border,
      shadowColor: shadowColor,
      borderColor: canTap ? borderColor : AppColors.borderStrong,
      radius: NsTokens.radius,
      depth: NsTokens.buttonDepth,
      semanticLabel: label,
      child: SizedBox(
        height: height,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: isLoading
                ? SizedBox(
                    key: const ValueKey('loader'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation<Color>(onPrimary),
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: onPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (icon != null) ...[
                        const SizedBox(width: 10),
                        Icon(icon, size: 20, color: onPrimary),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
