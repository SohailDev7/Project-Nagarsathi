import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'ns_mascot.dart';

/// One title and one mascot line of dialogue.
///
/// Sathi carries the supporting message in a speech bubble instead of a topic
/// chip or a second subtitle, so each screen keeps a single voice.
class NsAuthHeading extends StatelessWidget {
  const NsAuthHeading({
    super.key,
    required this.title,
    required this.message,
    this.mood = NsMascotMood.idle,
    this.look = const Offset(0, 0.6),
    this.wave = false,
    this.mascotSize = 64,
  });

  final String title;
  final String message;
  final NsMascotMood mood;
  final Offset look;
  final bool wave;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NsMascot(size: mascotSize, mood: mood, look: look, wave: wave),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  color: AppColors.forest,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(height: 7),
              _MascotBubble(message: message),
            ],
          ),
        ),
      ],
    );
  }
}

class _MascotBubble extends StatelessWidget {
  const _MascotBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
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
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
        ),
        Positioned(
          left: -5.5,
          top: 9,
          child: Transform.rotate(
            angle: 0.785,
            child: Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  left: BorderSide(color: AppColors.borderStrong, width: 1.5),
                  bottom: BorderSide(color: AppColors.borderStrong, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
