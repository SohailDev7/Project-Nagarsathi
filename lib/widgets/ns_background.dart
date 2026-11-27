import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Calm civic backdrop: warm cream paper (or deep forest in dark mode) with an
/// optional lightweight radial glow at the top behind Sathi.
///
/// Uses a single GPU-friendly [RadialGradient] without blur filters so
/// scrolling and transitions stay locked at 60/120fps.
class NsBackground extends StatelessWidget {
  const NsBackground({
    super.key,
    required this.child,
    this.staff = false,
    this.ambientGlow = false,
  });

  final Widget child;
  final bool staff;
  final bool ambientGlow;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = staff ? tokens.staffBackground : tokens.background;

    if (!ambientGlow) {
      return ColoredBox(color: baseColor, child: child);
    }

    final glowColor = staff
        ? (isDark
              ? const Color(0xFF1DB954).withValues(alpha: 0.14)
              : const Color(0xFF1B8A5A).withValues(alpha: 0.18))
        : (isDark
              ? AppColors.primary.withValues(alpha: 0.14)
              : const Color(0xFF74D654).withValues(alpha: 0.28));

    final secondaryGlow = isDark
        ? AppColors.sky.withValues(alpha: 0.06)
        : AppColors.sun.withValues(alpha: 0.16);

    return ColoredBox(
      color: baseColor,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.78),
                      radius: 1.05,
                      colors: [glowColor, secondaryGlow, Colors.transparent],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
