import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Borderless back affordance.
class NsBackButton extends StatelessWidget {
  const NsBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        tooltip: 'Back',
        icon: const Icon(Icons.arrow_back_rounded, size: 21),
      ),
    );
  }
}
