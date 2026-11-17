import 'package:material_ui/material_ui.dart';

/// Springy fade-up used as screens enter. Finite, so tests settle cleanly.
class NsEntrance extends StatefulWidget {
  const NsEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 520),
    this.offset = const Offset(0, 20),
    this.scale = 0.97,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;
  final double scale;

  @override
  State<NsEntrance> createState() => _NsEntranceState();
}

class _NsEntranceState extends State<NsEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final total = (widget.delay + widget.duration).inMilliseconds;
        final elapsed = _controller.value * total - widget.delay.inMilliseconds;
        final raw = (elapsed / widget.duration.inMilliseconds).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(raw);
        final opacity = (raw * 3).clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(
              widget.offset.dx * (1 - eased),
              widget.offset.dy * (1 - eased),
            ),
            child: Transform.scale(
              scale: widget.scale + (1 - widget.scale) * eased,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
