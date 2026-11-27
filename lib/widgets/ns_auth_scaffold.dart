import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'ns_background.dart';

/// Compact single-viewport shell for every auth screen.
///
/// The top bar stays pinned so navigation and preferences are always reachable
/// without scrolling. Uses keyboard-aware smooth scrolling so opening the soft
/// keyboard never jumps or clips form controls.
class NsAuthScaffold extends StatelessWidget {
  const NsAuthScaffold({
    super.key,
    required this.child,
    this.topBar,
    this.bottom,
    this.staff = false,
    this.ambientGlow = true,
    this.maxWidth = 430,
    this.centerContent = false,
  });

  final Widget child;
  final Widget? topBar;
  final Widget? bottom;
  final bool staff;
  final bool ambientGlow;
  final double maxWidth;

  /// Centres short forms in the space under the top bar instead of leaving a
  /// tall empty gap at the bottom of the screen.
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NsBackground(
        staff: staff,
        ambientGlow: ambientGlow,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final horizontal = constraints.maxWidth < 380 ? 16.0 : 22.0;
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
                        4,
                      ),
                      child: SizedBox(width: contentWidth, child: topBar),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, body) {
                        return SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            horizontal,
                            10,
                            horizontal,
                            24,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: centerContent
                                  ? math.max(0, body.maxHeight - 34)
                                  : 0,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: contentWidth,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [child],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (bottom != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        4,
                        horizontal,
                        14,
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
