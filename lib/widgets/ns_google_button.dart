import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_pressable.dart';

/// White "Continue with Google" action that matches the chunky auth buttons.
class NsGoogleButton extends StatelessWidget {
  const NsGoogleButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  @override
  Widget build(BuildContext context) {
    final canTap = !isLoading && onPressed != null;

    return NsPressable(
      onTap: canTap ? onPressed : null,
      color: AppColors.surface,
      shadowColor: AppColors.shadow,
      borderColor: AppColors.borderStrong,
      radius: NsTokens.radius,
      depth: NsTokens.buttonDepth,
      semanticLabel: label,
      child: SizedBox(
        height: 52,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: isLoading
                ? const SizedBox(
                    key: ValueKey('loader'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      valueColor: AlwaysStoppedAnimation(AppColors.primaryDeep),
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/icon/google_g.png',
                        width: 19,
                        height: 19,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.forest,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Small "or continue with" divider shown above third-party sign-in.
class NsAuthDivider extends StatelessWidget {
  const NsAuthDivider({super.key, this.label = 'or continue with'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.borderStrong)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.muted,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.borderStrong)),
      ],
    );
  }
}
