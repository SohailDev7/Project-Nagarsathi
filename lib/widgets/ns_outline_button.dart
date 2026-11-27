import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum NsOutlineTone { neutral, green, danger }

/// Sleek flat-modern secondary action with subtle border and tap scale.
class NsOutlineButton extends StatefulWidget {
  const NsOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 50,
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
  State<NsOutlineButton> createState() => _NsOutlineButtonState();
}

class _NsOutlineButtonState extends State<NsOutlineButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);
    final enabled = widget.onPressed != null;
    final (border, foreground, fill) = switch (widget.tone) {
      NsOutlineTone.neutral => (
        tokens.border,
        tokens.heading,
        tokens.surfaceSoft,
      ),
      NsOutlineTone.green => (
        tokens.primaryStrong.withValues(alpha: 0.5),
        tokens.accentText,
        tokens.mint,
      ),
      NsOutlineTone.danger => (
        tokens.errorBorder.withValues(alpha: 0.55),
        scheme.error,
        tokens.errorBorder.withValues(alpha: 0.08),
      ),
    };

    final box = Container(
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: enabled ? fill : tokens.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? border : tokens.hairline,
          width: 1.4,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: enabled ? foreground : tokens.muted,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            if (widget.icon != null) ...[
              const SizedBox(width: 8),
              Icon(
                widget.icon,
                size: 18,
                color: enabled ? foreground : tokens.muted,
              ),
            ],
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled
              ? (_) {
                  HapticFeedback.selectionClick();
                  setState(() => _pressed = true);
                }
              : null,
          onTapUp: (_) {
            if (_pressed) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (_pressed) setState(() => _pressed = false);
          },
          onTap: enabled ? widget.onPressed : null,
          child: AnimatedScale(
            scale: _pressed && enabled ? 0.985 : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: widget.expand ? SizedBox(width: double.infinity, child: box) : box,
          ),
        ),
      ),
    );
  }
}
