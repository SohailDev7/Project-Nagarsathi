import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Flat background used by every screen.
class NsBackground extends StatelessWidget {
  const NsBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppColors.background, child: child);
  }
}
