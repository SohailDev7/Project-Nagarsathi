import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_mascot.dart';

/// One title and one mascot line of dialogue.
///
/// Sathi carries the supporting message in a speech bubble instead of a topic
/// chip or a second subtitle, so each screen keeps a single voice. The mascot
/// sits on the right so the greeting reads first.
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
    final mascot = NsMascot(
      size: mascotSize,
      mood: mood,
      look: look,
      wave: wave,
    );
    final copy = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w900,
              color: AppColors.forest,
              letterSpacing: -0.9,
            ),
          ),
          const SizedBox(height: 8),
          _MascotBubble(message: message, tailOnRight: mascotOnRight),
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

class _MascotBubble extends StatelessWidget {
  const _MascotBubble({required this.message, this.tailOnRight = true});

  final String message;
  final bool tailOnRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(11, 7, 11, 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(tailOnRight ? 14 : 4),
              topRight: Radius.circular(tailOnRight ? 4 : 14),
              bottomLeft: const Radius.circular(14),
              bottomRight: const Radius.circular(14),
            ),
            border: Border.all(color: AppColors.borderStrong, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                offset: const Offset(0, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              message,
              key: ValueKey(message),
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
        ),
        Positioned(
          right: tailOnRight ? -5.5 : null,
          left: tailOnRight ? null : -5.5,
          top: 9,
          child: Transform.rotate(
            angle: 0.785,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: tailOnRight
                    ? const Border(
                        top: BorderSide(
                          color: AppColors.borderStrong,
                          width: 1.5,
                        ),
                        right: BorderSide(
                          color: AppColors.borderStrong,
                          width: 1.5,
                        ),
                      )
                    : const Border(
                        left: BorderSide(
                          color: AppColors.borderStrong,
                          width: 1.5,
                        ),
                        bottom: BorderSide(
                          color: AppColors.borderStrong,
                          width: 1.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
