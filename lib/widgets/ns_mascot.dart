import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

enum NsMascotMood { idle, happy, curious, sad, celebrate }

/// "Sathi", the NagarSathi civic buddy.
///
/// A compact, sticker-like character drawn entirely in Flutter. Motion is
/// limited to a finites intro pop, one blink and short reactions so it stays
/// smooth, accessible and test-friendly.
class NsMascot extends StatefulWidget {
  const NsMascot({
    super.key,
    this.size = 96,
    this.mood = NsMascotMood.idle,
    this.look = Offset.zero,
    this.wave = false,
  });

  final double size;
  final NsMascotMood mood;

  /// Pupil direction, roughly -1..1 on each axis.
  final Offset look;
  final bool wave;

  @override
  State<NsMascot> createState() => _NsMascotState();
}

class _NsMascotState extends State<NsMascot> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  );
  late final AnimationController _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );

  bool _started = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward();
    }
  }

  @override
  void didUpdateWidget(covariant NsMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood == widget.mood || _reduceMotion) return;

    if (widget.mood == NsMascotMood.celebrate) {
      _react.repeat(count: 2, reverse: true);
    } else {
      _react.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _react.dispose();
    super.dispose();
  }

  double _pulse(double t, double start, double end) {
    if (t <= start || t >= end) return 0;
    final progress = (t - start) / (end - start);
    return math.sin(progress * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _react]),
        builder: (context, _) {
          final entrance = Curves.easeOutBack.transform(
            _intro.value.clamp(0.0, 1.0),
          );
          final react = math.sin(_react.value * math.pi);
          final happy =
              widget.mood == NsMascotMood.happy ||
              widget.mood == NsMascotMood.celebrate;
          final blink = math.max(
            _pulse(_intro.value, 0.5, 0.6),
            _pulse(_intro.value, 0.76, 0.84),
          );
          final wave = (widget.wave || happy)
              ? math.sin(_intro.value * math.pi * 4) *
                        (1 - _intro.value) *
                        0.7 +
                    math.sin(_react.value * math.pi * 2) * 0.18
              : 0.0;

          return Opacity(
            opacity: _intro.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - entrance) * 12 - react * 3),
              child: Transform.scale(
                scale: (0.84 + 0.16 * entrance) * (1 + react * 0.02),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _MascotPainter(
                      mood: widget.mood,
                      look: widget.look,
                      blink: blink,
                      wave: wave,
                      celebrate: happy ? _react.value : 0,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MascotPainter extends CustomPainter {
  const _MascotPainter({
    required this.mood,
    required this.look,
    required this.blink,
    required this.wave,
    required this.celebrate,
  });

  final NsMascotMood mood;
  final Offset look;
  final double blink;
  final double wave;
  final double celebrate;

  bool get _happy =>
      mood == NsMascotMood.happy || mood == NsMascotMood.celebrate;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate(0, size.height - s);

    _paintShadow(canvas, s);
    _paintArm(canvas, s, left: true, angle: 0.1);
    _paintArm(canvas, s, left: false, angle: -0.1 - wave);
    _paintFeet(canvas, s);
    _paintBody(canvas, s);
    _paintSprout(canvas, s);
    _paintBelly(canvas, s);
    _paintCheeks(canvas, s);
    _paintEyes(canvas, s);
    _paintMouth(canvas, s);

    canvas.restore();
  }

  void _paintShadow(Canvas canvas, double s) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.93 * s),
        width: 0.46 * s,
        height: 0.06 * s,
      ),
      Paint()..color = AppColors.forest.withValues(alpha: 0.1),
    );
  }

  void _paintArm(
    Canvas canvas,
    double s, {
    required bool left,
    required double angle,
  }) {
    canvas.save();
    canvas.translate((left ? 0.18 : 0.82) * s, 0.58 * s);
    canvas.rotate(angle);
    final arm = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(0, 0.08 * s),
        width: 0.1 * s,
        height: 0.18 * s,
      ),
      Radius.circular(0.05 * s),
    );
    canvas.drawRRect(arm, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      Offset(0, 0.17 * s),
      0.052 * s,
      Paint()..color = AppColors.primaryLight,
    );
    canvas.restore();
  }

  void _paintFeet(Canvas canvas, double s) {
    final paint = Paint()..color = AppColors.primaryDark;
    for (final x in [0.405, 0.595]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x * s, 0.875 * s),
            width: 0.12 * s,
            height: 0.065 * s,
          ),
          Radius.circular(0.035 * s),
        ),
        paint,
      );
    }
  }

  void _paintBody(Canvas canvas, double s) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.18 * s, 0.235 * s, 0.64 * s, 0.64 * s),
      Radius.circular(0.3 * s),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9BEA5A), AppColors.primary, Color(0xFF4CBB00)],
          stops: [0, 0.55, 1],
        ).createShader(body.outerRect),
    );

    // Soft top-left sheen and a grounded bottom shade.
    canvas.save();
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.44 * s, 0.39 * s),
        width: 0.3 * s,
        height: 0.2 * s,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.85 * s),
        width: 0.4 * s,
        height: 0.07 * s,
      ),
      Paint()..color = AppColors.primaryDark.withValues(alpha: 0.14),
    );
  }

  void _paintSprout(Canvas canvas, double s) {
    final stem = Paint()
      ..color = AppColors.primaryDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(0.5 * s, 0.25 * s)
        ..quadraticBezierTo(0.48 * s, 0.19 * s, 0.5 * s, 0.145 * s),
      stem,
    );

    _leaf(canvas, s, center: Offset(0.44 * s, 0.185 * s), angle: -0.75);
    _leaf(canvas, s, center: Offset(0.565 * s, 0.165 * s), angle: 0.6);
  }

  void _leaf(
    Canvas canvas,
    double s, {
    required Offset center,
    required double angle,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final leaf = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: 0.15 * s, height: 0.075 * s),
      Radius.circular(0.05 * s),
    );
    canvas.drawRRect(leaf, Paint()..color = AppColors.primaryLight);
    canvas.drawRRect(
      leaf,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.009 * s
        ..color = AppColors.primaryDeep.withValues(alpha: 0.5),
    );
    canvas.restore();
  }

  void _paintBelly(Canvas canvas, double s) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.74 * s),
        width: 0.3 * s,
        height: 0.17 * s,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _paintCheeks(Canvas canvas, double s) {
    final paint = Paint()..color = AppColors.blush.withValues(alpha: 0.45);
    canvas.drawCircle(Offset(0.3 * s, 0.59 * s), 0.043 * s, paint);
    canvas.drawCircle(Offset(0.7 * s, 0.59 * s), 0.043 * s, paint);
  }

  void _paintEyes(Canvas canvas, double s) {
    const eyeY = 0.455;
    final eyeRadius = 0.105 * s;
    final sad = mood == NsMascotMood.sad;

    for (final x in [0.395, 0.605]) {
      final center = Offset(x * s, eyeY * s);

      if (_happy && mood != NsMascotMood.curious) {
        // Happy closed eyes: two little upward arcs.
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - 0.06 * s, center.dy + 0.015 * s)
            ..quadraticBezierTo(
              center.dx,
              center.dy - 0.055 * s,
              center.dx + 0.06 * s,
              center.dy + 0.015 * s,
            ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.022 * s
            ..strokeCap = StrokeCap.round
            ..color = AppColors.forest,
        );
        continue;
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, (1 - blink * 0.9).clamp(0.06, 1));
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: eyeRadius * 2.05,
          height: eyeRadius * 2.2,
        ),
        Paint()..color = Colors.white,
      );
      final pupilShift = Offset(
        look.dx.clamp(-1.0, 1.0) * 0.038 * s,
        look.dy.clamp(-1.0, 1.0) * 0.032 * s + (sad ? 0.016 * s : 0),
      );
      canvas.drawCircle(
        pupilShift,
        eyeRadius * 0.5,
        Paint()..color = AppColors.forest,
      );
      canvas.drawCircle(
        pupilShift.translate(-eyeRadius * 0.18, -eyeRadius * 0.2),
        eyeRadius * 0.17,
        Paint()..color = Colors.white,
      );
      canvas.restore();
    }

    if (sad) {
      final browPaint = Paint()
        ..color = AppColors.forestSoft
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.02 * s
        ..strokeCap = StrokeCap.round;
      for (final (index, x) in [0.395, 0.605].indexed) {
        final direction = index == 0 ? 1.0 : -1.0;
        canvas.drawLine(
          Offset(x * s - 0.05 * s * direction, 0.34 * s),
          Offset(x * s + 0.04 * s * direction, 0.365 * s),
          browPaint,
        );
      }
    }
  }

  void _paintMouth(Canvas canvas, double s) {
    final stroke = Paint()
      ..color = AppColors.forest
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018 * s
      ..strokeCap = StrokeCap.round;

    switch (mood) {
      case NsMascotMood.idle:
        canvas.drawPath(
          Path()
            ..moveTo(0.46 * s, 0.6 * s)
            ..quadraticBezierTo(0.5 * s, 0.64 * s, 0.54 * s, 0.6 * s),
          stroke,
        );
        break;
      case NsMascotMood.curious:
        canvas.drawCircle(
          Offset(0.5 * s, 0.615 * s),
          0.018 * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.018 * s
            ..color = AppColors.forest,
        );
        break;
      case NsMascotMood.sad:
        canvas.drawPath(
          Path()
            ..moveTo(0.46 * s, 0.63 * s)
            ..quadraticBezierTo(0.5 * s, 0.59 * s, 0.54 * s, 0.63 * s),
          stroke,
        );
        break;
      case NsMascotMood.happy:
      case NsMascotMood.celebrate:
        final width = 0.075 + celebrate * 0.01;
        canvas.drawPath(
          Path()
            ..moveTo((0.5 - width) * s, 0.595 * s)
            ..quadraticBezierTo(
              0.5 * s,
              (0.595 + width * 1.9) * s,
              (0.5 + width) * s,
              0.595 * s,
            )
            ..close(),
          Paint()..color = AppColors.forest,
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0.5 * s, 0.635 * s),
            width: 0.045 * s,
            height: 0.02 * s,
          ),
          Paint()..color = AppColors.blush,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.look != look ||
        oldDelegate.blink != blink ||
        oldDelegate.wave != wave ||
        oldDelegate.celebrate != celebrate;
  }
}
