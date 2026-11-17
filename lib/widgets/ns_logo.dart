import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// NagarSathi app mark, identical to the launcher icon.
class NsLogo extends StatelessWidget {
  const NsLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.04),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icon/icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        semanticLabel: 'NagarSathi',
      ),
    );
  }
}
