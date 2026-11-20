import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Rounded surface with a thick border and a hard bottom edge.
class NsCard extends StatelessWidget {
  const NsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
    this.shadowColor,
    this.radius = NsTokens.cardRadius,
    this.depth = NsTokens.cardDepth,
    this.width,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Defaults to [NsColors.surface].
  final Color? color;

  /// Defaults to [NsColors.border].
  final Color? borderColor;

  /// Defaults to [NsColors.shadow].
  final Color? shadowColor;
  final double radius;
  final double depth;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);

    return Container(
      width: width,
      margin: EdgeInsets.only(bottom: depth),
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? tokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? tokens.border,
          width: NsTokens.borderWidth,
        ),
        boxShadow: [
          if (depth > 0)
            BoxShadow(
              color: shadowColor ?? tokens.shadow,
              offset: Offset(0, depth),
              blurRadius: 0,
            ),
        ],
      ),
      child: child,
    );
  }
}
