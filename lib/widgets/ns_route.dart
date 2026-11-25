import 'package:material_ui/material_ui.dart';

/// Transition styles across NagarSathi.
enum NsTransitionStyle {
  /// Fast, smooth cross-fade + micro-zoom (0.975 -> 1.0), zero sideways sweep.
  fadeZoom,

  /// Pure crisp cross-fade for top-level switches (e.g., Login -> Home).
  fade,
}

/// Custom route with GPU-composited transitions (zero offscreen `saveLayer`).
class NsPageRoute<T> extends PageRouteBuilder<T> {
  NsPageRoute({
    required WidgetBuilder builder,
    this.style = NsTransitionStyle.fadeZoom,
    super.settings,
    super.fullscreenDialog,
  }) : super(
         transitionDuration: const Duration(milliseconds: 210),
         reverseTransitionDuration: const Duration(milliseconds: 180),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final reduceMotion =
               MediaQuery.maybeDisableAnimationsOf(context) ?? false;
           if (reduceMotion) return child;

           return buildNsTransition(
             style: style,
             animation: animation,
             secondaryAnimation: secondaryAnimation,
             child: child,
           );
         },
       );

  final NsTransitionStyle style;
}

/// Shared transition builder used by both [NsPageRoute] and [PageTransitionsTheme].
Widget buildNsTransition({
  required NsTransitionStyle style,
  required Animation<double> animation,
  required Animation<double> secondaryAnimation,
  required Widget child,
}) {
  final fade = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  if (style == NsTransitionStyle.fade) {
    return FadeTransition(opacity: fade, child: child);
  }

  final scale = Tween<double>(begin: 0.975, end: 1.0).animate(fade);

  return FadeTransition(
    opacity: fade,
    child: ScaleTransition(scale: scale, child: child),
  );
}

/// Theme-level page transitions builder so named and standard routes feel fluid.
class NsSharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const NsSharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) return child;

    return buildNsTransition(
      style: NsTransitionStyle.fadeZoom,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}
