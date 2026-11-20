import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Thick, rounded step meter with a bright tip marker.
class NsStepProgress extends StatelessWidget {
  const NsStepProgress({
    super.key,
    required this.step,
    required this.total,
    this.height = 16,
  });

  final int step;
  final int total;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = NsColors.of(context);
    final fraction = total <= 0 ? 0.0 : ((step + 1) / total).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: tokens.surfaceSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: tokens.border, width: 2),
          ),
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1 / total, end: fraction),
              duration: const Duration(milliseconds: 460),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: value,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.primary,
                                tokens.accentBright,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 5),
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
