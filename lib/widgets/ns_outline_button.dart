import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_pressable.dart';

enum NsOutlineTone { neutral, green, danger }

/// Secondary action with the same chunky press physics as the primary button.
class NsOutlineButton extends StatelessWidget {
  const NsOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.tone = NsOutlineTone.neutral,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final NsOutlineTone tone;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);
    final enabled = onPressed != null;
    final (border, foreground, fill) = switch (tone) {
      NsOutlineTone.neutral => (
        tokens.controlBorder,
        tokens.heading,
        tokens.surface,
      ),
      NsOutlineTone.green => (
        tokens.primaryStrong,
        tokens.accentText,
        tokens.mint,
      ),
      NsOutlineTone.danger => (
        tokens.errorBorder,
        scheme.error,
        tokens.surface,
      ),
    };

    return NsPressable(
      onTap: enabled ? onPressed : null,
      color: enabled ? fill : tokens.surfaceSoft,
      borderColor: enabled ? border : tokens.hairline,
      shadowColor: border,
      radius: NsTokens.radius,
      depth: enabled ? 4 : 0,
      expand: expand,
      semanticLabel: label,
      child: SizedBox(
        height: height,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: enabled ? foreground : tokens.muted,
                  letterSpacing: 0.1,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(
                  icon,
                  size: 18,
                  color: enabled ? foreground : tokens.muted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
