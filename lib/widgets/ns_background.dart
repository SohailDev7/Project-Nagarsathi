import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Soft green-glow backdrop shared by all auth screens.
class NsBackground extends StatelessWidget {
  const NsBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(child: ColoredBox(color: AppColors.background)),
        Positioned(
          top: -140,
          right: -110,
          child: _Glow(
            size: 340,
            color: AppColors.primary.withValues(alpha: 0.16),
          ),
        ),
        Positioned(
          bottom: -170,
          left: -130,
          child: _Glow(
            size: 320,
            color: AppColors.primaryLight.withValues(alpha: 0.14),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
