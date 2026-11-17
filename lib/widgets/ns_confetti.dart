import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// One-shot confetti burst for successful actions.
class NsConfetti extends StatefulWidget {
  const NsConfetti({super.key, this.onCompleted, this.pieces = 46});

  final VoidCallback? onCompleted;
  final int pieces;

  @override
  State<NsConfetti> createState() => _NsConfettiState();
}

class _NsConfettiState extends State<NsConfetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );
  late final List<_ConfettiPiece> _pieces = _buildPieces();
  bool _started = false;

  static const _colors = [
    AppColors.primary,
    AppColors.primaryLight,
    AppColors.sun,
    AppColors.sky,
    AppColors.blush,
    AppColors.forest,
    Colors.white,
  ];

  List<_ConfettiPiece> _buildPieces() {
    final random = math.Random(21);
    return List.generate(widget.pieces, (index) {
      return _ConfettiPiece(
        startX: 0.5 + (random.nextDouble() - 0.5) * 0.18,
        startY: 0.44 + (random.nextDouble() - 0.5) * 0.08,
        angle: -math.pi / 2 + (random.nextDouble() - 0.5) * 2.3,
        speed: 0.55 + random.nextDouble() * 0.75,
        width: 7 + random.nextDouble() * 7,
        height: 10 + random.nextDouble() * 10,
        rotation: random.nextDouble() * math.pi,
        spin: (random.nextDouble() - 0.5) * 14,
        phase: random.nextDouble() * math.pi * 2,
        color: _colors[index % _colors.length],
        circle: index % 4 == 0,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted?.call();
      });
      return;
    }

    _controller.forward().whenComplete(() {
      if (mounted) widget.onCompleted?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return CustomPaint(
              painter: _ConfettiPainter(
                pieces: _pieces,
                progress: _controller.value,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.speed,
    required this.width,
    required this.height,
    required this.rotation,
    required this.spin,
    required this.phase,
    required this.color,
    required this.circle,
  });

  final double startX;
  final double startY;
  final double angle;
  final double speed;
  final double width;
  final double height;
  final double rotation;
  final double spin;
  final double phase;
  final Color color;
  final bool circle;
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter({required this.pieces, required this.progress});

  final List<_ConfettiPiece> pieces;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;

    final t = progress * 1.5;
    final base = size.shortestSide;
    final gravity = base * 2.1;

    for (final piece in pieces) {
      final vx = math.cos(piece.angle) * piece.speed * base;
      final vy = math.sin(piece.angle) * piece.speed * base;
      final x =
          size.width * piece.startX +
          vx * t +
          math.sin(t * 7 + piece.phase) * 0.018 * base;
      final y = size.height * piece.startY + vy * t + 0.5 * gravity * t * t;
      if (y > size.height + 40) continue;

      final fade = progress < 0.62
          ? 1.0
          : (1 - (progress - 0.62) / 0.38).clamp(0.0, 1.0);
      final paint = Paint()..color = piece.color.withValues(alpha: 0.9 * fade);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(piece.rotation + piece.spin * t);
      if (piece.circle) {
        canvas.drawCircle(Offset.zero, piece.width * 0.5, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.width,
              height: piece.height,
            ),
            const Radius.circular(2.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
