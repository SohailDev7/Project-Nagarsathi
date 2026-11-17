import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'ns_background.dart';

/// Compact single-viewport shell for every auth screen.
///
/// The top bar stays pinned so entry points such as the staff portal are
/// always reachable without scrolling. Short forms sit directly under it and
/// the body only scrolls on very small screens or with the keyboard open.
class NsAuthScaffold extends StatelessWidget {
  const NsAuthScaffold({
    super.key,
    required this.child,
    this.topBar,
    this.bottom,
    this.staff = false,
    this.maxWidth = 430,
  });

  final Widget child;
  final Widget? topBar;
  final Widget? bottom;
  final bool staff;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NsBackground(
        staff: staff,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth < 380 ? 18.0 : 24.0;
              final available = math.max(
                0.0,
                constraints.maxWidth - horizontal * 2,
              );
              final contentWidth = math.min(maxWidth, available);

              return Column(
                children: [
                  if (topBar != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        10,
                        horizontal,
                        0,
                      ),
                      child: SizedBox(width: contentWidth, child: topBar),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        12,
                        horizontal,
                        24,
                      ),
                      child: Center(
                        child: SizedBox(
                          width: contentWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [child],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (bottom != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        4,
                        horizontal,
                        16,
                      ),
                      child: SizedBox(width: contentWidth, child: bottom),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
