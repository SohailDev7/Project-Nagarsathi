import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Controller that triggers a gentle horizontal damped-sine shake on errors.
class NsShakeController extends ChangeNotifier {
  int _triggerCount = 0;

  int get triggerCount => _triggerCount;

  void shake() {
    _triggerCount++;
    notifyListeners();
  }
}

/// Wraps a form or card to give immediate horizontal shake feedback on errors.
class NsShake extends StatefulWidget {
  const NsShake({
    super.key,
    required this.controller,
    required this.child,
    this.amplitude = 7.0,
    this.duration = const Duration(milliseconds: 360),
  });

  final NsShakeController controller;
  final Widget child;
  final double amplitude;
  final Duration duration;

  @override
  State<NsShake> createState() => _NsShakeState();
}

class _NsShakeState extends State<NsShake> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onShake);
  }

  @override
  void didUpdateWidget(covariant NsShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onShake);
      widget.controller.addListener(_onShake);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onShake);
    _anim.dispose();
    super.dispose();
  }

  void _onShake() {
    if (!mounted) return;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return;
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      child: widget.child,
      builder: (context, child) {
        final t = _anim.value;
        if (t == 0 || t == 1) return child!;
        final damping = 1.0 - t;
        final dx = math.sin(t * math.pi * 5) * widget.amplitude * damping;
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
    );
  }
}
