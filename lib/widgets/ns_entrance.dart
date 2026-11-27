import 'package:material_ui/material_ui.dart';

/// GPU-composited springy fade-up used as screens enter.
///
/// Uses [FadeTransition], [SlideTransition], and [ScaleTransition] instead of
/// [Opacity] so the engine never allocates an offscreen `saveLayer`.
class NsEntrance extends StatefulWidget {
  const NsEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 360),
    this.offset = const Offset(0, 16),
    this.scale = 0.98,
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
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final totalMs = mathMax(1, (widget.delay + widget.duration).inMilliseconds);
    final delayFraction = (widget.delay.inMilliseconds / totalMs).clamp(
      0.0,
      0.95,
    );

    final curved = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayFraction, 1.0, curve: Curves.easeOutCubic),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delayFraction,
        (delayFraction + (1.0 - delayFraction) * 0.65).clamp(0.0, 1.0),
        curve: Curves.easeOut,
      ),
    );
    _slide = Tween<Offset>(
      begin: Offset(widget.offset.dx * 0.02, widget.offset.dy * 0.002),
      end: Offset.zero,
    ).animate(curved);
    _scale = Tween<double>(begin: widget.scale, end: 1.0).animate(curved);
  }

  static int mathMax(int a, int b) => a > b ? a : b;

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
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
