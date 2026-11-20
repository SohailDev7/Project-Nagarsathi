import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Calm civic backdrop: warm cream paper with two soft green glows.
///
/// Deliberately free of grids, sparkles and repeating decoration so the auth
/// screens stay quiet and the content gets all the attention.
class NsBackground extends StatelessWidget {
  const NsBackground({super.key, required this.child, this.staff = false});

  final Widget child;
  final bool staff;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        ColoredBox(
          color: staff ? tokens.staffBackground : tokens.background,
        ),
        Positioned(
          top: -190,
          right: -140,
          child: _Glow(
            size: 430,
            color: scheme.primary.withValues(alpha: staff ? 0.14 : 0.17),
          ),
        ),
        Positioned(
          bottom: -210,
          left: -150,
          child: _Glow(
            size: 400,
            color: tokens.accentBright.withValues(alpha: 0.12),
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
