import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Gently animated line-art skyline used to fill empty space in the wizard.
///
/// Wrapped in a [RepaintBoundary] so the subtle loop never dirties parent
/// widgets or form inputs.
class NsCityArt extends StatefulWidget {
  const NsCityArt({super.key, this.height = 128});

  final double height;

  @override
  State<NsCityArt> createState() => _NsCityArtState();
}

class _NsCityArtState extends State<NsCityArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (reduceMotion) {
      _controller.stop();
      if (_controller.value == 0) _controller.value = 0.4;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final palette = isDark
        ? _CityPalette(
            fill: const Color(0xFF20332A),
            line: const Color(0xFF3A5745),
            sun: scheme.primary,
            mote: tokens.accentBright,
            window: tokens.accentBright,
          )
        : _CityPalette(
            fill: const Color(0xFFEDF3EF),
            line: const Color(0xFFD9E4DD),
            sun: scheme.primary,
            mote: scheme.primary,
            window: scheme.primary,
          );

    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _CityPainter(
                  progress: _controller.value,
                  palette: palette,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Skyline colours for one theme.
@immutable
class _CityPalette {
  const _CityPalette({
    required this.fill,
    required this.line,
    required this.sun,
    required this.mote,
    required this.window,
  });

  final Color fill;
  final Color line;
  final Color sun;
  final Color mote;
  final Color window;

  @override
  bool operator ==(Object other) {
    return other is _CityPalette &&
        other.fill == fill &&
        other.line == line &&
        other.sun == sun &&
        other.mote == mote &&
        other.window == window;
  }

  @override
  int get hashCode => Object.hash(fill, line, sun, mote, window);
}

class _CityPainter extends CustomPainter {
  const _CityPainter({required this.progress, required this.palette});

  final double progress;
  final _CityPalette palette;

  static const _buildings = <(double, double, double)>[
    (0.04, 0.15, 0.42),
    (0.19, 0.12, 0.68),
    (0.30, 0.17, 0.52),
    (0.46, 0.13, 0.82),
    (0.58, 0.19, 0.60),
    (0.76, 0.12, 0.36),
    (0.87, 0.09, 0.50),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final baseY = size.height - 10;

    final buildingFill = Paint()
      ..style = PaintingStyle.fill
      ..color = palette.fill;
    final buildingLine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = palette.line;

    final sunCenter = Offset(
      width * 0.8,
      size.height * 0.22 - (progress - 0.5) * 6,
    );
    canvas.drawCircle(
      sunCenter,
      14,
      Paint()..color = palette.sun.withValues(alpha: 0.09),
    );
    canvas.drawCircle(
      sunCenter,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = palette.sun.withValues(alpha: 0.32),
    );

    final drift = (progress - 0.5) * 14;
    final mote = Paint()..color = palette.mote.withValues(alpha: 0.22);
    canvas.drawCircle(
      Offset(width * 0.22 + drift, size.height * 0.18),
      2.6,
      mote,
    );
    canvas.drawCircle(
      Offset(width * 0.42 + drift * 0.55, size.height * 0.10),
      1.9,
      mote,
    );

    final windowPaint = Paint();
    for (var index = 0; index < _buildings.length; index++) {
      final (xFactor, widthFactor, heightFactor) = _buildings[index];
      final rect = Rect.fromLTWH(
        width * xFactor,
        baseY - size.height * heightFactor,
        width * widthFactor,
        size.height * heightFactor,
      );
      final body = RRect.fromRectAndRadius(rect, const Radius.circular(5));
      canvas.drawRRect(body, buildingFill);
      canvas.drawRRect(body, buildingLine);

      _paintWindows(canvas, rect, index, windowPaint);
    }

    canvas.drawLine(
      Offset(0, baseY),
      Offset(width, baseY),
      buildingLine,
    );
  }

  void _paintWindows(
    Canvas canvas,
    Rect building,
    int seed,
    Paint windowPaint,
  ) {
    final columns = building.width > 40 ? 2 : 1;
    final spacing = building.width / (columns + 1);
    final rows = math.max(1, (building.height / 22).floor());

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        if ((row * 3 + column + seed) % 4 == 1) continue;

        final center = Offset(
          building.left + spacing * (column + 1),
          building.top + 12 + row * 16,
        );
        if (center.dy > building.bottom - 6) continue;

        final pulse =
            0.16 + 0.14 * math.sin((progress * math.pi * 2) + row + seed);
        windowPaint.color = palette.window.withValues(alpha: pulse);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 4.5, height: 4.5),
            const Radius.circular(1.4),
          ),
          windowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CityPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.palette != palette;
  }
}
