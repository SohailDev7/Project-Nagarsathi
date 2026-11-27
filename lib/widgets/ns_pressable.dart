import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A pressable surface with Duolingo-style depth and zero shadow-lerp jank.
///
/// The button sits on a hard coloured shadow. Pressing translates it smoothly
/// into the shadow via a GPU-composited transform instead of interpolating
/// `BoxDecoration` shadows on every frame.
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

class _NsPressableState extends State<NsPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
    reverseDuration: const Duration(milliseconds: 110),
  );
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (!_enabled) return;
    if (widget.haptic) HapticFeedback.selectionClick();
    _pressed = true;
    _press.forward();
  }

  void _up() {
    if (!_pressed) return;
    _pressed = false;
    _press.reverse();
  }

  void _cancel() {
    if (!_pressed) return;
    _pressed = false;
    _press.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final depth = _enabled ? widget.depth : 0.0;

    final staticContent = DecoratedBox(
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.radius),
        border: widget.borderWidth == 0
            ? null
            : Border.all(color: widget.borderColor, width: widget.borderWidth),
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    final surface = AnimatedBuilder(
      animation: _press,
      child: staticContent,
      builder: (context, child) {
        final t = Curves.easeOut.transform(_press.value);
        final translateY = depth * t;
        final shadowHeight = depth * (1.0 - t);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (_enabled && shadowHeight > 0.1)
              Positioned(
                left: 0,
                right: 0,
                top: depth,
                bottom: -depth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.shadowColor,
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(0, translateY),
              child: Transform.scale(
                scale: 1.0 - 0.012 * t,
                child: child,
              ),
            ),
          ],
        );
      },
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
