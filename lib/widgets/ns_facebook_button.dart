import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_pressable.dart';

/// Facebook-blue "Continue with Facebook" button matching the chunky Duolingo
/// style of [NsGoogleButton].
class NsFacebookButton extends StatelessWidget {
  const NsFacebookButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Facebook',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  static const _fbBlue = Color(0xFF1877F2);
  static const _fbBlueDark = Color(0xFF0D5BBF);
  static const _fbBlueBorder = Color(0xFF1467D2);

  @override
  Widget build(BuildContext context) {
    final canTap = !isLoading && onPressed != null;

    return NsPressable(
      onTap: canTap ? onPressed : null,
      color: _fbBlue,
      shadowColor: _fbBlueDark,
      borderColor: _fbBlueBorder,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.facebook_rounded,
                        size: 22,
                        color: Colors.white,
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
                            color: Colors.white,
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
