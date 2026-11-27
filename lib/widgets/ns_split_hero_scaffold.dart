import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Bold full-bleed split hero + overlapping rounded sheet shell for auth screens.
///
/// Renders a tinted gradient wash with a static 4% dot-grid texture behind
/// Sathi / brand hero content, meeting an overlapping rounded surface sheet.
class NsSplitHeroScaffold extends StatelessWidget {
  const NsSplitHeroScaffold({
    super.key,
    required this.topBar,
    required this.hero,
    required this.sheetChild,
    this.staff = false,
    this.maxWidth = 440,
  });

  final Widget topBar;
  final Widget hero;
  final Widget sheetChild;
  final bool staff;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final heroGradient = staff
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF061F15),
              Color(0xFF0D3322),
              Color(0xFF164C34),
            ],
          )
        : (isDark
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF051F15),
                    Color(0xFF0B3020),
                    Color(0xFF11462D),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF125632),
                    Color(0xFF1B7445),
                    Color(0xFF268E55),
                  ],
                ));

    final sheetColor = staff
        ? (isDark ? tokens.surface : const Color(0xFFB4D9CB))
        : tokens.surface;

    final dotColor = staff
        ? const Color(0xFFF5B731).withValues(alpha: 0.06)
        : (isDark
              ? AppColors.primaryLight.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.08));

    return Scaffold(
      backgroundColor: sheetColor,
      body: Stack(
        children: [
          // Full-bleed top hero backdrop extending cleanly behind the sheet lip.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360,
            child: RepaintBoundary(
              child: DecoratedBox(
                decoration: BoxDecoration(gradient: heroGradient),
                child: CustomPaint(
                  painter: _DotGridPainter(color: dotColor),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth < 380 ? 16.0 : 22.0;
                final contentWidth = math.min(
                  maxWidth,
                  math.max(0.0, constraints.maxWidth - horizontal * 2),
                );

                return Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        10,
                        horizontal,
                        4,
                      ),
                      child: Center(
                        child: SizedBox(width: contentWidth, child: topBar),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(0, constraints.maxHeight - 58),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  6,
                                  horizontal,
                                  0,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: contentWidth,
                                    child: hero,
                                  ),
                                ),
                              ),
                              // Overlapping rounded sheet
                              Container(
                                width: double.infinity,
                                constraints: BoxConstraints(
                                  minHeight: math.max(
                                    0,
                                    constraints.maxHeight - 230,
                                  ),
                                ),
                                decoration: BoxDecoration(
                                  color: sheetColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(30),
                                  ),
                                  border: Border(
                                    top: BorderSide(
                                      color: staff
                                          ? (isDark
                                                ? const Color(0xFF245238)
                                                : const Color(0xFFE4ECE7))
                                          : tokens.border.withValues(
                                              alpha: 0.7,
                                            ),
                                      width: 1.2,
                                    ),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.32 : 0.06,
                                      ),
                                      blurRadius: 20,
                                      offset: const Offset(0, -6),
                                    ),
                                  ],
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  22,
                                  horizontal,
                                  MediaQuery.paddingOf(context).bottom + 24,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: contentWidth,
                                    child: sheetChild,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  const _DotGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 22.0;
    for (double y = 12; y < size.height; y += spacing) {
      for (double x = 12; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.35, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter oldDelegate) =>
      oldDelegate.color != color;
}
