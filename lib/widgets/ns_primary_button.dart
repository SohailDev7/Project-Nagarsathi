import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Flat primary action button with a built-in loading state.
class NsPrimaryButton extends StatelessWidget {
  const NsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final canTap = !isLoading && onPressed != null;

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Material(
        color: canTap
            ? AppColors.primary
            : AppColors.primary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canTap ? onPressed : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loader'),
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Row(
                      key: const ValueKey('label'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 8),
                          Icon(icon, size: 18, color: Colors.white),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
