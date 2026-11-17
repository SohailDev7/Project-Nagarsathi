import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// NagarSathi app mark with a chunky sticker-style frame.
class NsLogo extends StatelessWidget {
  const NsLogo({super.key, this.size = 48, this.depth = 3});

  final double size;
  final double depth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size + depth,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          if (depth > 0)
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.28),
              offset: Offset(0, depth),
              blurRadius: 0,
            ),
        ],
      ),
      child: Container(
        padding: EdgeInsets.all(size * 0.035),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.3),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.55),
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/icon/icon.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          semanticLabel: 'NagarSathi',
        ),
      ),
    );
  }
}

/// Logo plus the NagarSathi wordmark.
class NsBrand extends StatelessWidget {
  const NsBrand({super.key, this.logoSize = 44, this.compact = false});

  final double logoSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NsLogo(size: logoSize),
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NagarSathi',
              style: TextStyle(
                fontSize: compact ? 17 : 18,
                height: 1.05,
                fontWeight: FontWeight.w900,
                color: AppColors.forest,
                letterSpacing: -0.5,
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 3),
              const Text(
                'YOUR CITY, BY YOUR SIDE',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDeep,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
