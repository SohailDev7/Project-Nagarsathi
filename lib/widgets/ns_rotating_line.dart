import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// A single line of copy that gently rotates through friendly alternatives.
///
/// It holds still when the platform asks for reduced motion, and each timer is
/// cancelled with the widget so tests never leave a pending timer behind.
class NsRotatingLine extends StatefulWidget {
  const NsRotatingLine({
    super.key,
    required this.lines,
    this.interval = const Duration(seconds: 8),
    this.style,
    this.maxLines = 2,
    this.textAlign = TextAlign.start,
  });

  final List<String> lines;
  final Duration interval;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;

  @override
  State<NsRotatingLine> createState() => _NsRotatingLineState();
}

class _NsRotatingLineState extends State<NsRotatingLine> {
  Timer? _timer;
  int _index = 0;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (!_started) {
      _started = true;
      _reduceMotion = reduce;
      _restart();
      return;
    }

    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    _restart();
  }

  @override
  void didUpdateWidget(covariant NsRotatingLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameLines(oldWidget.lines, widget.lines)) {
      _index = 0;
      _restart();
    } else if (oldWidget.interval != widget.interval) {
      _restart();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _sameLines(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _restart() {
    _timer?.cancel();
    if (!mounted || _reduceMotion || widget.lines.length < 2) return;

    _timer = Timer.periodic(widget.interval, (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % widget.lines.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) return const SizedBox.shrink();

    final line = widget.lines[_index % widget.lines.length];
    final text = Text(
      line,
      key: ValueKey(line),
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: widget.textAlign,
      style: widget.style,
    );

    if (_reduceMotion) return text;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final offset = Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: offset, child: child),
        );
      },
      child: text,
    );
  }
}
