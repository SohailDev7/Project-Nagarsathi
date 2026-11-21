import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_mascot.dart';
import 'ns_speech_bubble.dart';

/// One title and one mascot line of dialogue.
///
/// Sathi the yeti carries the supporting message in a speech bubble instead of
/// a topic chip or a second subtitle, so each screen keeps a single voice. The
/// mascot sits on the right so the greeting reads first.
class NsAuthHeading extends StatelessWidget {
  const NsAuthHeading({
    super.key,
    required this.title,
    required this.message,
    this.mood = NsMascotMood.idle,
    this.look = const Offset(0, 0.6),
    this.wave = false,
    this.mascotSize = 64,
    this.mascotOnRight = true,
  });

  final String title;
  final String message;
  final NsMascotMood mood;
  final Offset look;
  final bool wave;
  final double mascotSize;
  final bool mascotOnRight;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final mascot = NsMascot(
      size: mascotSize,
      mood: mood,
      look: look,
      wave: wave,
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
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: tokens.heading,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 8),
          NsSpeechBubble(
            messages: [message],
            speaker: 'Sathi the Yeti',
            tailOnRight: mascotOnRight,
            tone: tone,
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: mascotOnRight
          ? [copy, const SizedBox(width: 10), mascot]
          : [mascot, const SizedBox(width: 10), copy],
    );
  }
}
