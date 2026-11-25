import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_mascot.dart';
import 'ns_speech_bubble.dart';

/// Shared hero flight shuttle so text styles never flash yellow underlines.
Widget nsHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection flightDirection,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  return Material(
    type: MaterialType.transparency,
    child: toHeroContext.widget,
  );
}

/// Compact hero header with Sathi the yeti and a stable floating speech pill.
///
/// The mascot sits inside an optional [Hero] so it glides smoothly between
/// Login, Sign Up, Forgot Password, and Staff Login without layout jumps.
class NsAuthHeading extends StatelessWidget {
  const NsAuthHeading({
    super.key,
    required this.title,
    required this.message,
    this.mood = NsMascotMood.idle,
    this.look = const Offset(0, 0.6),
    this.wave = false,
    this.mascotSize = 68,
    this.mascotOnRight = true,
    this.heroTag,
  });

  final String title;
  final String message;
  final NsMascotMood mood;
  final Offset look;
  final bool wave;
  final double mascotSize;
  final bool mascotOnRight;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final rawMascot = NsMascot(
      size: mascotSize,
      mood: mood,
      look: look,
      wave: wave,
    );
    final mascot = heroTag == null
        ? rawMascot
        : Hero(
            tag: heroTag!,
            flightShuttleBuilder: nsHeroShuttle,
            child: rawMascot,
          );

    final tone = switch (mood) {
      NsMascotMood.sad => NsSpeechTone.error,
      NsMascotMood.celebrate => NsSpeechTone.success,
      NsMascotMood.curious => NsSpeechTone.info,
      _ => NsSpeechTone.neutral,
    };

    final copy = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 27,
              height: 1.06,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 54),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: NsSpeechBubble(
                messages: [message],
                speaker: 'Sathi the Yeti',
                tailOnRight: mascotOnRight,
                tone: tone,
              ),
            ),
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: mascotOnRight
          ? [copy, const SizedBox(width: 12), mascot]
          : [mascot, const SizedBox(width: 12), copy],
    );
  }
}
