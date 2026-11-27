import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Sathi's expression set.
///
/// [sleepy] keeps the eyes gently closed, [angry] narrows them behind a scowl
/// and [excited] throws them wide with a sparkle. Each mood also drives its own
/// motion: a tremble, a slow sleepy sway or an extra hop.
enum NsMascotMood {
  idle,
  happy,
  curious,
  sad,
  angry,
  sleepy,
  celebrate,
  excited,
}

/// "Sathi", the NagarSathi yeti.
///
/// A friendly snow yeti drawn entirely in Flutter. The idle loop breathes,
/// sways, blinks, twitches an ear and now and then waves, while mood changes
/// add a short reaction bounce. Expressions range from happy and curious to sad,
/// angry, sleepy (eyes closed) and excited, each with its own face and motion.
/// Every loop is finite and self-scheduling, so it settles in tests and respects
/// reduced-motion settings.
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
    duration: const Duration(milliseconds: 620),
  );
  late final AnimationController _react = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  Timer? _idleTimer;
  bool _started = false;
  bool _reduceMotion = false;
  int _idleCycles = 0;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scheduleIdle(delay: const Duration(milliseconds: 1400));
      }
    });
    _idle.addStatusListener((status) {
      // Run one gentle breath settle after intro/interaction instead of a
      // continuous background repaint loop.
      if (status == AnimationStatus.completed && _idleCycles < 1) {
        _scheduleIdle(delay: const Duration(milliseconds: 2200));
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (!_started) {
      _started = true;
      _reduceMotion = reduce;
      if (reduce) {
        _intro.value = 1;
      } else {
        _intro.forward();
      }
      return;
    }

    if (reduce == _reduceMotion) return;
    _reduceMotion = reduce;
    if (reduce) {
      _idleTimer?.cancel();
      _idle.stop();
    } else {
      _scheduleIdle(delay: const Duration(milliseconds: 600));
    }
  }

  @override
  void didUpdateWidget(covariant NsMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mood == widget.mood &&
        oldWidget.wave == widget.wave &&
        oldWidget.look == widget.look) {
      return;
    }
    if (_reduceMotion) return;

    if (widget.mood == NsMascotMood.celebrate ||
        widget.mood == NsMascotMood.excited) {
      _react.repeat(count: 2, reverse: true);
    } else if (widget.mood == NsMascotMood.angry) {
      // A short, trembling huff rather than a single bounce.
      _react.repeat(count: 3);
    } else if (oldWidget.mood != widget.mood || oldWidget.wave != widget.wave) {
      _react.forward(from: 0);
      _idle.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _intro.dispose();
    _react.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _scheduleIdle({Duration delay = const Duration(milliseconds: 1300)}) {
    _idleTimer?.cancel();
    if (!mounted || _reduceMotion) return;
    _idleTimer = Timer(delay, () {
      if (!mounted || _reduceMotion) return;
      _idleCycles++;
      _idle.forward(from: 0);
    });
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
        animation: Listenable.merge([_intro, _react, _idle]),
        builder: (context, _) {
          final entrance = Curves.easeOutBack.transform(
            _intro.value.clamp(0.0, 1.0),
          );
          final react = math.sin(_react.value * math.pi);
          final idle = _idle.value;
          final phase = idle * math.pi * 2;
          final reduce = _reduceMotion;

          final mood = widget.mood;
          final angry = mood == NsMascotMood.angry;
          final sleepy = mood == NsMascotMood.sleepy;
          final excited = mood == NsMascotMood.excited;
          final celebrationMood =
              mood == NsMascotMood.celebrate || excited;

          final breathe = reduce
              ? 0.0
              : math.sin(phase) * (sleepy ? 1.5 : 1.0);
          final sway = reduce
              ? 0.0
              : math.sin(phase) * (sleepy ? 0.016 : 0.024);
          final scarfSway = reduce ? 0.0 : math.sin(phase + 0.9);
          final blink = reduce || sleepy
              ? 0.0
              : math.max(_pulse(idle, 0.18, 0.225), _pulse(idle, 0.63, 0.665));
          final earTwitch = reduce ? 0.0 : _pulse(idle, 0.44, 0.49);
          final idleWave = (!reduce && (_idleCycles - 1) % 3 == 0)
              ? _pulse(idle, 0.76, 0.92)
              : 0.0;
          final wave = reduce
              ? (widget.wave ? 0.9 : 0.0)
              : (angry || sleepy
                    ? 0.0
                    : (widget.wave
                          ? math.sin(phase * 2) * 0.45 + react * 0.9
                          : idleWave * 0.9 + react * 0.35));
          final celebrate = reduce
              ? (celebrationMood ? 1.0 : 0.0)
              : (celebrationMood ? math.max(react, idleWave * 0.7) : 0.0);
          final bounce = react * (excited ? 4.5 : 3) + celebrate * 1.5;
          // An angry huff shakes the whole yeti, fading as the reaction ends.
          final tremble = (!reduce && angry)
              ? math.sin(_react.value * math.pi * 18) *
                    math.sin(_react.value * math.pi) *
                    0.012
              : 0.0;
          final scale = (0.82 + 0.18 * entrance) * (1 + react * 0.02);

          return FadeTransition(
            opacity: _intro,
            child: Transform.translate(
              offset: Offset(
                tremble * widget.size,
                (1 - entrance) * 14 - bounce,
              ),
              child: Transform.scale(
                scaleX: scale * (1 - breathe * 0.006),
                scaleY: scale * (1 + breathe * 0.012),
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Semantics(
                    image: true,
                    label: 'Sathi the yeti mascot',
                    child: CustomPaint(
                      painter: _MascotPainter(
                        mood: widget.mood,
                        look: widget.look,
                        blink: blink,
                        wave: wave,
                        celebrate: celebrate,
                        breathe: breathe,
                        sway: sway,
                        earTwitch: earTwitch,
                        scarfSway: scarfSway,
                        reaction: reduce
                            ? (celebrationMood ? 1.0 : 0.0)
                            : _react.value,
                        idlePhase: idle,
                      ),
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
    required this.breathe,
    required this.sway,
    required this.earTwitch,
    required this.scarfSway,
    required this.reaction,
    required this.idlePhase,
  });

  final NsMascotMood mood;
  final Offset look;
  final double blink;
  final double wave;
  final double celebrate;
  final double breathe;
  final double sway;
  final double earTwitch;
  final double scarfSway;

  /// Progress (0..1) of the current mood reaction, used by one-shot effects.
  final double reaction;

  /// Progress (0..1) of the idle breath cycle.
  final double idlePhase;

  static const _furLight = Color(0xFFFDFEFF);
  static const _furBase = Color(0xFFF1FAFF);
  static const _furShade = Color(0xFFD3E8F6);
  static const _furDeep = Color(0xFF9EC6DC);
  static const _faceTint = Color(0xFFE8F6FF);
  static const _innerEar = Color(0xFFBFDCEC);
  static const _nose = Color(0xFF7295AC);
  static const _belly = Color(0xFFF7FCFF);

  bool get _happy =>
      mood == NsMascotMood.happy || mood == NsMascotMood.celebrate;
  bool get _sad => mood == NsMascotMood.sad;
  bool get _curious => mood == NsMascotMood.curious;
  bool get _angry => mood == NsMascotMood.angry;
  bool get _sleepy => mood == NsMascotMood.sleepy;
  bool get _excited =>
      mood == NsMascotMood.excited || mood == NsMascotMood.celebrate;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate(0, size.height - s);

    _paintShadow(canvas, s);

    canvas.save();
    canvas.translate(0.5 * s, 0.9 * s);
    canvas.rotate(sway);
    canvas.translate(-0.5 * s, -0.9 * s);

    _paintEars(canvas, s);
    _paintArms(canvas, s);
    _paintBody(canvas, s);
    _paintFurDetails(canvas, s);
    _paintFeet(canvas, s);
    _paintBelly(canvas, s);
    _paintScarf(canvas, s);
    _paintFace(canvas, s);
    _paintCheeks(canvas, s);
    _paintEyes(canvas, s);
    _paintNose(canvas, s);
    _paintMouth(canvas, s);
    _paintMoodEffects(canvas, s);
    _paintTuft(canvas, s);

    canvas.restore();
    _paintSparkles(canvas, s);
    canvas.restore();
  }

  static final Map<double, _MascotCache> _cache = <double, _MascotCache>{};

  static _MascotCache _cacheFor(double s) {
    final existing = _cache[s];
    if (existing != null) return existing;
    if (_cache.length >= 6) _cache.clear();
    final created = _MascotCache.build(s);
    _cache[s] = created;
    return created;
  }

  void _paintShadow(Canvas canvas, double s) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.955 * s),
        width: 0.46 * s * (1 + breathe * 0.02),
        height: 0.05 * s,
      ),
      Paint()..color = AppColors.forest.withValues(alpha: 0.1),
    );
  }

  void _paintEars(Canvas canvas, double s) {
    final outer = Paint()..color = _furShade;
    final inner = Paint()..color = _innerEar;

    // Ears flatten outward when cross, droop when sleepy or low, and perk up
    // when excited.
    final droop = _excited
        ? -0.1
        : (_angry ? 0.26 : (_sleepy ? 0.2 : (_sad ? 0.14 : 0.0)));

    for (final (left, x, angle) in [
      (true, 0.285, -0.38),
      (false, 0.715, 0.38),
    ]) {
      canvas.save();
      canvas.translate(x * s, 0.205 * s);
      canvas.rotate(
        angle -
            droop * (left ? 1 : -1) +
            (left ? 1 : -1) * earTwitch * 0.18,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 0.18 * s, height: 0.2 * s),
        outer,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, 0.012 * s),
          width: 0.1 * s,
          height: 0.12 * s,
        ),
        inner,
      );
      canvas.restore();
    }
  }

  void _paintArms(Canvas canvas, double s) {
    // Cross moods tuck both arms in; celebration throws the free arm higher.
    final hunch = _angry ? 0.22 : 0.0;
    final lift = _angry || _sleepy ? 0.0 : celebrate * 0.35;
    _paintArm(
      canvas,
      s,
      left: true,
      angle: 0.12 + scarfSway * 0.02 + hunch,
    );
    _paintArm(
      canvas,
      s,
      left: false,
      angle: -0.12 - wave * 0.9 - hunch - lift,
    );
  }

  void _paintArm(
    Canvas canvas,
    double s, {
    required bool left,
    required double angle,
  }) {
    canvas.save();
    canvas.translate((left ? 0.19 : 0.81) * s, 0.55 * s);
    canvas.rotate(angle);

    final armRect = Rect.fromCenter(
      center: Offset(0, 0.12 * s),
      width: 0.135 * s,
      height: 0.26 * s,
    );
    final arm = RRect.fromRectAndRadius(armRect, Radius.circular(0.07 * s));
    canvas.drawRRect(
      arm,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_furLight, _furShade],
        ).createShader(armRect),
    );

    final paw = Offset(0, 0.245 * s);
    canvas.drawCircle(paw, 0.07 * s, Paint()..color = _furBase);
    canvas.drawCircle(
      paw,
      0.07 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.01 * s
        ..color = _furDeep.withValues(alpha: 0.35),
    );

    final toe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.01 * s
      ..strokeCap = StrokeCap.round
      ..color = _furDeep.withValues(alpha: 0.5);
    for (final dx in [-0.022, 0.0, 0.022]) {
      canvas.drawLine(
        paw.translate(dx * s, 0.022 * s),
        paw.translate(dx * s, 0.044 * s),
        toe,
      );
    }

    canvas.restore();
  }

  void _paintBody(Canvas canvas, double s) {
    final cache = _cacheFor(s);
    final body = cache.bodyPath;

    canvas.drawPath(body, cache.bodyFillPaint);

    canvas.save();
    canvas.clipPath(body);

    canvas.save();
    canvas.translate(0.5 * s, 0.5 * s);
    canvas.rotate(-0.32);
    canvas.translate(-0.5 * s, -0.5 * s);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.43 * s, 0.36 * s),
        width: 0.34 * s,
        height: 0.22 * s,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );
    canvas.restore();

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.85 * s),
        width: 0.56 * s,
        height: 0.16 * s,
      ),
      Paint()..color = _furShade.withValues(alpha: 0.55),
    );
    canvas.restore();

    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.012 * s
        ..color = _furDeep.withValues(alpha: 0.35),
    );
  }

  void _paintFurDetails(Canvas canvas, double s) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.011 * s
      ..strokeCap = StrokeCap.round
      ..color = _furDeep.withValues(alpha: 0.35);

    final tufts = [
      (0.23, 0.45, 0.20, 0.49, 0.23, 0.53),
      (0.77, 0.46, 0.80, 0.50, 0.77, 0.54),
      (0.28, 0.74, 0.25, 0.77, 0.28, 0.80),
      (0.72, 0.75, 0.75, 0.78, 0.72, 0.81),
    ];
    for (final (x1, y1, cx, cy, x2, y2) in tufts) {
      canvas.drawPath(
        Path()
          ..moveTo(x1 * s, y1 * s)
          ..quadraticBezierTo(cx * s, cy * s, x2 * s, y2 * s),
        stroke,
      );
    }
  }

  void _paintFeet(Canvas canvas, double s) {
    final toe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.009 * s
      ..strokeCap = StrokeCap.round
      ..color = _furDeep.withValues(alpha: 0.6);

    for (final x in [0.355, 0.645]) {
      final center = Offset(x * s, 0.9 * s);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: 0.25 * s, height: 0.125 * s),
        Paint()..color = _furShade,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(0, -0.01 * s),
          width: 0.2 * s,
          height: 0.09 * s,
        ),
        Paint()..color = _furBase,
      );

      for (final dx in [-0.045, 0.0, 0.045]) {
        canvas.drawLine(
          center.translate(dx * s, 0.025 * s),
          center.translate(dx * s, 0.045 * s),
          toe,
        );
      }
    }
  }

  void _paintBelly(Canvas canvas, double s) {
    final rect = Rect.fromCenter(
      center: Offset(0.5 * s, 0.755 * s),
      width: 0.34 * s,
      height: 0.16 * s,
    );
    canvas.drawOval(rect, Paint()..color = _belly.withValues(alpha: 0.9));
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.008 * s
        ..color = _furDeep.withValues(alpha: 0.18),
    );

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.008 * s
      ..strokeCap = StrokeCap.round
      ..color = _furDeep.withValues(alpha: 0.22);
    canvas.drawPath(
      Path()
        ..moveTo(0.44 * s, 0.72 * s)
        ..quadraticBezierTo(0.47 * s, 0.74 * s, 0.45 * s, 0.77 * s),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0.55 * s, 0.73 * s)
        ..quadraticBezierTo(0.52 * s, 0.75 * s, 0.54 * s, 0.78 * s),
      stroke,
    );
  }

  void _paintScarf(Canvas canvas, double s) {
    final band = Path()
      ..moveTo(0.215 * s, 0.625 * s)
      ..quadraticBezierTo(0.5 * s, 0.705 * s, 0.785 * s, 0.625 * s)
      ..lineTo(0.775 * s, 0.695 * s)
      ..quadraticBezierTo(0.5 * s, 0.775 * s, 0.225 * s, 0.695 * s)
      ..close();

    canvas.drawPath(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primaryLight,
            AppColors.primary,
            AppColors.primaryDark,
          ],
          stops: [0, 0.6, 1],
        ).createShader(band.getBounds()),
    );
    canvas.drawPath(
      band,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.012 * s
        ..color = AppColors.primaryDeep.withValues(alpha: 0.45),
    );

    final knot = Rect.fromCenter(
      center: Offset(0.735 * s, 0.685 * s),
      width: 0.1 * s,
      height: 0.09 * s,
    );
    final knotShape = RRect.fromRectAndRadius(knot, Radius.circular(0.035 * s));
    canvas.drawRRect(knotShape, Paint()..color = AppColors.primaryDark);
    canvas.drawRRect(
      knotShape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.01 * s
        ..color = AppColors.primaryDeep.withValues(alpha: 0.5),
    );

    final sway = scarfSway * 0.028 * s;
    final tail = Path()
      ..moveTo(0.71 * s, 0.69 * s)
      ..quadraticBezierTo(
        0.80 * s + sway,
        0.75 * s,
        0.755 * s + sway,
        0.835 * s,
      )
      ..lineTo(0.685 * s + sway, 0.815 * s)
      ..quadraticBezierTo(0.72 * s, 0.75 * s, 0.665 * s, 0.70 * s)
      ..close();
    canvas.drawPath(
      tail,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primaryDark],
        ).createShader(tail.getBounds()),
    );
    canvas.drawPath(
      tail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.011 * s
        ..color = AppColors.primaryDeep.withValues(alpha: 0.5),
    );

    final fringe = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.009 * s
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryDeep.withValues(alpha: 0.55);
    for (final dx in [0.70, 0.725, 0.75]) {
      canvas.drawLine(
        Offset(dx * s + sway, 0.812 * s),
        Offset(dx * s + sway, 0.84 * s),
        fringe,
      );
    }
  }

  void _paintFace(Canvas canvas, double s) {
    final rect = Rect.fromCenter(
      center: Offset(0.5 * s, 0.465 * s),
      width: 0.54 * s,
      height: 0.4 * s,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Colors.white, _faceTint],
          stops: [0.55, 1],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.009 * s
        ..color = _furDeep.withValues(alpha: 0.18),
    );
  }

  void _paintCheeks(Canvas canvas, double s) {
    final paint = Paint()
      ..color = AppColors.blush.withValues(alpha: 0.42 + celebrate * 0.2);
    for (final x in [0.325, 0.675]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x * s, 0.552 * s),
          width: 0.09 * s,
          height: 0.055 * s,
        ),
        paint,
      );
    }
  }

  void _paintEyes(Canvas canvas, double s) {
    const eyeY = 0.45;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.021 * s
      ..strokeCap = StrokeCap.round
      ..color = AppColors.forest;

    if (_sleepy) {
      _paintClosedEyes(canvas, s, stroke);
      _paintBrows(canvas, s);
      return;
    }

    final closedHappy = _happy && !_curious;
    // A cross yeti narrows its eyes; an excited one opens them wider.
    final lidScale = _angry ? 0.58 : 1.0;

    for (final x in [0.39, 0.61]) {
      final center = Offset(x * s, eyeY * s);

      if (closedHappy) {
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - 0.058 * s, center.dy + 0.012 * s)
            ..quadraticBezierTo(
              center.dx,
              center.dy - 0.055 * s,
              center.dx + 0.058 * s,
              center.dy + 0.012 * s,
            ),
          stroke,
        );
        continue;
      }

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(
        1,
        ((1 - blink * 0.92) * lidScale).clamp(0.08, 1.0),
      );

      final eyeRect = Rect.fromCenter(
        center: Offset.zero,
        width: (_excited ? 0.172 : 0.155) * s,
        height: (_excited ? 0.192 : 0.175) * s,
      );
      canvas.drawOval(eyeRect, Paint()..color = Colors.white);
      canvas.drawOval(
        eyeRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.008 * s
          ..color = _furDeep.withValues(alpha: 0.4),
      );

      // Idle moods let the pupils drift a little so the stare stays alive.
      final wander = (_curious || _angry || _sad)
          ? 0.0
          : math.sin(idlePhase * math.pi * 2) * 0.006 * s;
      final pupil = Offset(
        look.dx.clamp(-1.0, 1.0) * 0.034 * s + wander,
        look.dy.clamp(-1.0, 1.0) * 0.03 * s + (_sad ? 0.014 * s : 0),
      );
      canvas.drawCircle(
        pupil,
        (_excited ? 0.05 : 0.044) * s,
        Paint()..color = AppColors.forest,
      );
      if (_excited) {
        // Star glint instead of the usual round highlight.
        _paintSparkle(
          canvas,
          pupil.translate(-0.014 * s, -0.016 * s),
          0.02 * s,
          Colors.white,
        );
      } else {
        canvas.drawCircle(
          pupil.translate(-0.015 * s, -0.018 * s),
          0.014 * s,
          Paint()..color = Colors.white,
        );
      }
      canvas.restore();
    }

    _paintBrows(canvas, s);
  }

  void _paintClosedEyes(Canvas canvas, double s, Paint stroke) {
    final lash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012 * s
      ..strokeCap = StrokeCap.round
      ..color = AppColors.forest.withValues(alpha: 0.75);

    for (final x in [0.39, 0.61]) {
      final center = Offset(x * s, 0.45 * s);
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - 0.06 * s, center.dy)
          ..quadraticBezierTo(
            center.dx,
            center.dy + 0.032 * s,
            center.dx + 0.06 * s,
            center.dy,
          ),
        stroke,
      );
      canvas.drawLine(
        Offset(center.dx - 0.052 * s, center.dy + 0.006 * s),
        Offset(center.dx - 0.072 * s, center.dy + 0.022 * s),
        lash,
      );
      canvas.drawLine(
        Offset(center.dx + 0.052 * s, center.dy + 0.006 * s),
        Offset(center.dx + 0.072 * s, center.dy + 0.022 * s),
        lash,
      );
    }
  }

  void _paintBrows(Canvas canvas, double s) {
    if (!_sad && !_curious && !_angry && !_excited) return;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.018 * s
      ..strokeCap = StrokeCap.round
      ..color = AppColors.forestSoft.withValues(alpha: 0.9);

    if (_angry) {
      // Inner ends drop toward the nose for a scowl.
      canvas.drawLine(
        Offset(0.325 * s, 0.352 * s),
        Offset(0.452 * s, 0.392 * s),
        stroke,
      );
      canvas.drawLine(
        Offset(0.548 * s, 0.392 * s),
        Offset(0.675 * s, 0.352 * s),
        stroke,
      );
      return;
    }

    if (_excited) {
      // Brows arc high for a delighted face.
      canvas.drawPath(
        Path()
          ..moveTo(0.325 * s, 0.374 * s)
          ..quadraticBezierTo(0.39 * s, 0.336 * s, 0.455 * s, 0.36 * s),
        stroke,
      );
      canvas.drawPath(
        Path()
          ..moveTo(0.545 * s, 0.36 * s)
          ..quadraticBezierTo(0.61 * s, 0.336 * s, 0.675 * s, 0.374 * s),
        stroke,
      );
      return;
    }

    if (_sad) {
      // Inner ends lift for a worried look.
      canvas.drawLine(
        Offset(0.33 * s, 0.378 * s),
        Offset(0.445 * s, 0.355 * s),
        stroke,
      );
      canvas.drawLine(
        Offset(0.555 * s, 0.355 * s),
        Offset(0.67 * s, 0.378 * s),
        stroke,
      );
      return;
    }

    // Curious: one brow raised, one relaxed.
    canvas.drawLine(
      Offset(0.335 * s, 0.372 * s),
      Offset(0.44 * s, 0.366 * s),
      stroke,
    );
    canvas.drawLine(
      Offset(0.555 * s, 0.355 * s),
      Offset(0.665 * s, 0.338 * s),
      stroke,
    );
  }

  void _paintNose(Canvas canvas, double s) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.5 * s, 0.523 * s),
        width: 0.078 * s,
        height: 0.055 * s,
      ),
      Paint()..color = _nose,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0.487 * s, 0.513 * s),
        width: 0.022 * s,
        height: 0.014 * s,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
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
            ..moveTo(0.462 * s, 0.585 * s)
            ..quadraticBezierTo(0.5 * s, 0.615 * s, 0.538 * s, 0.585 * s),
          stroke,
        );
        _paintFang(canvas, s, 0.528, 0.59, 0.016);
        break;
      case NsMascotMood.curious:
        canvas.drawCircle(
          Offset(0.5 * s, 0.598 * s),
          0.018 * s,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.017 * s
            ..color = AppColors.forest,
        );
        break;
      case NsMascotMood.sad:
        canvas.drawPath(
          Path()
            ..moveTo(0.462 * s, 0.612 * s)
            ..quadraticBezierTo(0.5 * s, 0.578 * s, 0.538 * s, 0.612 * s),
          stroke,
        );
        break;
      case NsMascotMood.sleepy:
        // A small mouth that breathes open and shut.
        final openness = 0.012 + (breathe.clamp(-1.0, 1.0) + 1) * 0.007;
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0.5 * s, 0.6 * s),
            width: 0.036 * s,
            height: openness * 2.2 * s,
          ),
          Paint()..color = AppColors.forest,
        );
        break;
      case NsMascotMood.angry:
        // Gritted zig-zag mouth with a tooth at each corner.
        canvas.drawPath(
          Path()
            ..moveTo(0.44 * s, 0.612 * s)
            ..lineTo(0.47 * s, 0.594 * s)
            ..lineTo(0.5 * s, 0.612 * s)
            ..lineTo(0.53 * s, 0.594 * s)
            ..lineTo(0.56 * s, 0.612 * s),
          stroke,
        );
        _paintFang(canvas, s, 0.46, 0.609, 0.014);
        _paintFang(canvas, s, 0.54, 0.609, 0.014);
        break;
      case NsMascotMood.happy:
      case NsMascotMood.celebrate:
      case NsMascotMood.excited:
        final width = 0.05 + celebrate * 0.012 + (_excited ? 0.01 : 0.0);
        final depth = 0.05 + celebrate * 0.012 + (_excited ? 0.012 : 0.0);
        canvas.drawPath(
          Path()
            ..moveTo((0.5 - width) * s, 0.575 * s)
            ..quadraticBezierTo(
              0.5 * s,
              (0.575 + depth * 1.2) * s,
              (0.5 + width) * s,
              0.575 * s,
            )
            ..close(),
          Paint()..color = AppColors.forest,
        );
        _paintTongue(canvas, s, 0.5, 0.575 + depth * 0.78, 0.06,
            _excited ? 0.014 : 0.0);
        _paintFang(canvas, s, 0.5 - width + 0.012, 0.577, 0.017);
        _paintFang(canvas, s, 0.5 + width - 0.012, 0.577, 0.017);
        break;
    }
  }

  void _paintTongue(
    Canvas canvas,
    double s,
    double x,
    double y,
    double width,
    double extra,
  ) {
    final rect = Rect.fromCenter(
      center: Offset(x * s, (y + 0.006) * s),
      width: (width + extra) * s,
      height: 0.022 * s,
    );
    canvas.drawOval(rect, Paint()..color = AppColors.blush);
  }

  void _paintFang(Canvas canvas, double s, double x, double y, double size) {
    canvas.drawPath(
      Path()
        ..moveTo((x - size) * s, y * s)
        ..lineTo((x + size) * s, y * s)
        ..lineTo(x * s, (y + size * 1.6) * s)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  void _paintTuft(Canvas canvas, double s) {
    canvas.save();
    canvas.translate(sway * s * 0.6, 0);

    final tuft = Path()
      ..moveTo(0.43 * s, 0.235 * s)
      ..quadraticBezierTo(0.43 * s, 0.16 * s, 0.49 * s, 0.185 * s)
      ..quadraticBezierTo(0.51 * s, 0.135 * s, 0.55 * s, 0.19 * s)
      ..quadraticBezierTo(0.6 * s, 0.175 * s, 0.575 * s, 0.24 * s)
      ..quadraticBezierTo(0.5 * s, 0.225 * s, 0.43 * s, 0.235 * s)
      ..close();

    canvas.drawPath(tuft, Paint()..color = _furLight);
    canvas.drawPath(
      tuft,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.01 * s
        ..color = _furDeep.withValues(alpha: 0.35),
    );

    canvas.restore();
  }

  /// Small mood-specific flourishes: anger steam, a tear, sleepy Zs, and
  /// excited speed lines. Drawn inside the sway transform so they follow the
  /// head.
  void _paintMoodEffects(Canvas canvas, double s) {
    if (_angry) _paintAngerMarks(canvas, s);
    if (_sad) _paintTear(canvas, s);
    if (_sleepy) _paintSleepZs(canvas, s);
    if (_excited) _paintExcitementLines(canvas, s);
  }

  void _paintAngerMarks(Canvas canvas, double s) {
    final pulse = math.sin(reaction.clamp(0.0, 1.0) * math.pi);
    final steam = AppColors.error.withValues(alpha: 0.08 + pulse * 0.4);

    for (final (x, dir) in [(0.235, -1.0), (0.765, 1.0)]) {
      for (var i = 0; i < 3; i++) {
        final t = i / 3;
        canvas.drawCircle(
          Offset(
            (x + dir * (0.012 + t * 0.05)) * s,
            (0.205 - t * 0.07 - pulse * 0.018) * s,
          ),
          (0.019 - t * 0.005) * s,
          Paint()..color = steam.withValues(alpha: (0.08 + pulse * 0.4) * (1 - t * 0.35)),
        );
      }
    }

    // The little cross "anger vein" above the brow.
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.014 * s
      ..strokeCap = StrokeCap.round
      ..color = AppColors.error.withValues(alpha: 0.5 + pulse * 0.3);
    final base = Offset(0.738 * s, 0.33 * s);
    for (final angle in [0.75, -0.75]) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      canvas.rotate(angle);
      canvas.drawArc(
        Rect.fromCenter(center: Offset.zero, width: 0.048 * s, height: 0.048 * s),
        math.pi * 0.9,
        math.pi * 0.9,
        false,
        stroke,
      );
      canvas.restore();
    }
  }

  void _paintTear(Canvas canvas, double s) {
    final t = reaction.clamp(0.0, 1.0);
    final dropY = 0.485 + t * 0.07;
    final paint = Paint()
      ..color = const Color(0xFF8CC9E8).withValues(alpha: 0.9 - t * 0.35);

    canvas.drawPath(
      Path()
        ..moveTo(0.385 * s, (dropY - 0.04) * s)
        ..lineTo(0.371 * s, (dropY - 0.012) * s)
        ..lineTo(0.399 * s, (dropY - 0.012) * s)
        ..close(),
      paint,
    );
    canvas.drawCircle(Offset(0.385 * s, dropY * s), 0.017 * s, paint);
  }

  void _paintSleepZs(Canvas canvas, double s) {
    final float = math.sin(idlePhase * math.pi * 2);
    final specs = [(0.73, 0.24, 0.055), (0.805, 0.18, 0.043), (0.862, 0.124, 0.033)];
    final color = AppColors.forestSoft.withValues(alpha: 0.5);

    for (var i = 0; i < specs.length; i++) {
      final (x, y, size) = specs[i];
      _paintZ(
        canvas,
        Offset(x * s, (y - float * 0.012 * (i + 1)) * s),
        size * s,
        color,
      );
    }
  }

  void _paintZ(Canvas canvas, Offset center, double size, Color color) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.24
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    canvas.drawPath(
      Path()
        ..moveTo(center.dx - size * 0.5, center.dy - size * 0.5)
        ..lineTo(center.dx + size * 0.5, center.dy - size * 0.5)
        ..lineTo(center.dx - size * 0.5, center.dy + size * 0.5)
        ..lineTo(center.dx + size * 0.5, center.dy + size * 0.5),
      stroke,
    );
  }

  void _paintExcitementLines(Canvas canvas, double s) {
    final strength = reaction.clamp(0.0, 1.0);
    if (strength <= 0.02) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.012 * s
      ..strokeCap = StrokeCap.round
      ..color = AppColors.sun.withValues(alpha: 0.75 * strength);

    for (final (x, dir) in [(0.17, -1.0), (0.83, 1.0)]) {
      for (var i = 0; i < 3; i++) {
        final y = 0.4 + i * 0.075;
        canvas.drawLine(
          Offset((x + dir * 0.06) * s, y * s),
          Offset((x + dir * (0.028 + strength * 0.028)) * s, y * s),
          paint,
        );
      }
    }
  }

  void _paintSparkles(Canvas canvas, double s) {
    final strength = mood == NsMascotMood.celebrate ||
            mood == NsMascotMood.excited
        ? math.max(celebrate, 0.35)
        : celebrate;
    if (strength <= 0.02) return;

    final specs = [
      (Offset(0.14, 0.30), 0.055, AppColors.sun),
      (Offset(0.86, 0.38), 0.045, AppColors.primaryLight),
      (Offset(0.78, 0.13), 0.04, AppColors.sun),
      (Offset(0.20, 0.57), 0.035, AppColors.primaryLight),
    ];
    for (final (center, size, color) in specs) {
      _paintSparkle(
        canvas,
        Offset(center.dx * s, center.dy * s),
        size * s,
        color.withValues(alpha: strength.clamp(0.0, 1.0)),
      );
    }
  }

  void _paintSparkle(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawPath(
      Path()
        ..moveTo(center.dx, center.dy - radius)
        ..quadraticBezierTo(
          center.dx + radius * 0.18,
          center.dy - radius * 0.18,
          center.dx + radius,
          center.dy,
        )
        ..quadraticBezierTo(
          center.dx + radius * 0.18,
          center.dy + radius * 0.18,
          center.dx,
          center.dy + radius,
        )
        ..quadraticBezierTo(
          center.dx - radius * 0.18,
          center.dy + radius * 0.18,
          center.dx - radius,
          center.dy,
        )
        ..quadraticBezierTo(
          center.dx - radius * 0.18,
          center.dy - radius * 0.18,
          center.dx,
          center.dy - radius,
        )
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) {
    return oldDelegate.mood != mood ||
        oldDelegate.look != look ||
        oldDelegate.blink != blink ||
        oldDelegate.wave != wave ||
        oldDelegate.celebrate != celebrate ||
        oldDelegate.breathe != breathe ||
        oldDelegate.sway != sway ||
        oldDelegate.earTwitch != earTwitch ||
        oldDelegate.scarfSway != scarfSway ||
        oldDelegate.reaction != reaction ||
        oldDelegate.idlePhase != idlePhase;
  }
}

/// Cached size-invariant paths and gradient paints for [_MascotPainter].
class _MascotCache {
  _MascotCache({required this.bodyPath, required this.bodyFillPaint});

  final Path bodyPath;
  final Paint bodyFillPaint;

  factory _MascotCache.build(double s) {
    const center = Offset(0.5, 0.54);
    const rx = 0.35;
    const ry = 0.34;
    const count = 16;
    final body = Path();

    for (var i = 0; i <= count; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / count;
      final point =
          Offset(
            center.dx + math.cos(angle) * rx,
            center.dy + math.sin(angle) * ry,
          ) *
          s;
      if (i == 0) {
        body.moveTo(point.dx, point.dy);
      } else {
        final mid = angle - math.pi / count;
        final control =
            Offset(
              center.dx + math.cos(mid) * rx * 1.055,
              center.dy + math.sin(mid) * ry * 1.055,
            ) *
            s;
        body.quadraticBezierTo(control.dx, control.dy, point.dx, point.dy);
      }
    }
    body.close();

    final rect = body.getBounds();
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_MascotPainter._furLight, _MascotPainter._furBase, _MascotPainter._furShade],
        stops: [0, 0.55, 1],
      ).createShader(rect);

    return _MascotCache(bodyPath: body, bodyFillPaint: fillPaint);
  }
}
