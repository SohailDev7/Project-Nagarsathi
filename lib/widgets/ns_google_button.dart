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
    final tokens = NsColors.of(context);
    final canTap = !isLoading && onPressed != null;

    return NsPressable(
      onTap: canTap ? onPressed : null,
      color: tokens.surface,
      shadowColor: tokens.shadow,
      borderColor: tokens.controlBorder,
      radius: NsTokens.radius,
      depth: NsTokens.buttonDepth,
      semanticLabel: label,
      child: SizedBox(
        height: 52,
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        tokens.accentText,
                      ),
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
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            color: tokens.heading,
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
    final tokens = NsColors.of(context);

    return Row(
      children: [
        Expanded(child: Divider(color: tokens.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: tokens.muted,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Expanded(child: Divider(color: tokens.border)),
      ],
    );
  }
}
