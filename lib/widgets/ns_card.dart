import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Rounded surface with a thick border and a hard bottom edge.
class NsCard extends StatelessWidget {
  const NsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color = AppColors.surface,
    this.borderColor = AppColors.borderStrong,
    this.shadowColor = AppColors.shadow,
    this.radius = NsTokens.cardRadius,
    this.depth = NsTokens.cardDepth,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final Color shadowColor;
  final double radius;
  final double depth;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: EdgeInsets.only(bottom: depth),
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: NsTokens.borderWidth),
        boxShadow: [
          if (depth > 0)
            BoxShadow(
              color: shadowColor,
              offset: Offset(0, depth),
              blurRadius: 0,
            ),
        ],
      ),
      child: child,
    );
  }
}
