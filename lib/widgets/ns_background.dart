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
    final tokens = NsColors.of(context);
    return ColoredBox(
      color: staff ? tokens.staffBackground : tokens.background,
      child: child,
    );
  }
}
