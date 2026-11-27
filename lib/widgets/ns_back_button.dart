import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Clean modern back affordance with subtle frosted/tinted surface.
class NsBackButton extends StatefulWidget {
  const NsBackButton({
    super.key,
    this.onPressed,
    this.icon = Icons.arrow_back_rounded,
    this.onDarkHeader = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final bool onDarkHeader;

  @override
  State<NsBackButton> createState() => _NsBackButtonState();
}

class _NsBackButtonState extends State<NsBackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final darkChrome = widget.onDarkHeader || isDark;

    final bgColor = widget.onDarkHeader
        ? (isDark
              ? const Color(0xFF081610).withValues(alpha: 0.78)
              : const Color(0xFF0C4225).withValues(alpha: 0.78))
        : (isDark
              ? Colors.white.withValues(alpha: 0.12)
              : tokens.surfaceSoft.withValues(alpha: 0.9));
    final borderColor = darkChrome
        ? Colors.white.withValues(alpha: 0.22)
        : tokens.border;
    final iconColor = darkChrome ? Colors.white : tokens.heading;

    return Semantics(
      button: true,
      label: 'Back',
      child: Tooltip(
        message: 'Back',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            setState(() => _pressed = true);
          },
          onTapUp: (_) {
            if (_pressed) setState(() => _pressed = false);
          },
          onTapCancel: () {
            if (_pressed) setState(() => _pressed = false);
          },
          onTap: widget.onPressed ?? () => Navigator.of(context).maybePop(),
          child: AnimatedScale(
            scale: _pressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.1),
              ),
              child: Center(
                child: Icon(widget.icon, size: 20, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
