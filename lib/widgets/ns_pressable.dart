import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A pressable surface with Duolingo-style depth.
///
/// The button sits on a hard coloured shadow. Pressing translates it into the
/// shadow so the action feels physical instead of flat.
class NsPressable extends StatefulWidget {
  const NsPressable({
    super.key,
    required this.child,
    required this.onTap,
    required this.color,
    required this.borderColor,
    required this.shadowColor,
    this.depth = 5,
    this.radius = 18,
    this.borderWidth = 2,
    this.padding = EdgeInsets.zero,
    this.haptic = true,
    this.semanticLabel,
    this.expand = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final Color shadowColor;
  final double depth;
  final double radius;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final bool haptic;
  final String? semanticLabel;
  final bool expand;

  @override
  State<NsPressable> createState() => _NsPressableState();
}

class _NsPressableState extends State<NsPressable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _down(TapDownDetails _) {
    if (!_enabled) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    setState(() => _pressed = true);
  }

  void _up() {
    if (!_pressed) return;
    setState(() => _pressed = false);
  }

  void _cancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final depth = _enabled ? widget.depth : 0.0;
    final pressed = _pressed && _enabled;

    final surface = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, pressed ? depth : 0, 0),
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: widget.borderWidth == 0
            ? null
            : Border.all(color: widget.borderColor, width: widget.borderWidth),
        boxShadow: pressed || !_enabled
            ? const []
            : [
                BoxShadow(
                  color: widget.shadowColor,
                  offset: Offset(0, depth),
                  blurRadius: 0,
                ),
              ],
      ),
      child: widget.child,
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _down,
          onTapUp: (_) => _up(),
          onTapCancel: _cancel,
          onTap: _enabled ? widget.onTap : null,
          child: Padding(
            padding: EdgeInsets.only(bottom: depth),
            child: widget.expand
                ? SizedBox(width: double.infinity, child: surface)
                : surface,
          ),
        ),
      ),
    );
  }
}
