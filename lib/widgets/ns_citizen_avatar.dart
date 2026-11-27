import 'package:material_ui/material_ui.dart';

import '../models/citizen_avatar.dart';
import '../theme/app_theme.dart';
import 'ns_mascot.dart';

/// The citizen's initials on their chosen colour, with an optional mascot
/// badge. Used on the home header, the profile header and the account sheet so
/// one avatar style follows the citizen everywhere.
class NsCitizenAvatar extends StatelessWidget {
  const NsCitizenAvatar({
    super.key,
    required this.initials,
    this.color = CitizenAvatarColor.fallback,
    this.size = 40,
    this.showBadge = false,
  });

  final String initials;
  final CitizenAvatarColor color;
  final double size;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final inner = size - (size >= 60 ? 8 : 4);
    final badgeSize = size * 0.3;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.background,
                  Color.lerp(color.background, Colors.black, 0.2)!,
                ],
              ),
              border: Border.all(
                color: color.foreground.withValues(alpha: 0.45),
                width: size >= 60 ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: size * 0.12,
                  offset: Offset(0, size * 0.04),
                ),
              ],
            ),
            child: Text(
              initials,
              maxLines: 1,
              style: TextStyle(
                fontSize: inner * 0.36,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
                color: color.foreground,
              ),
            ),
          ),
          if (showBadge)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: badgeSize,
                height: badgeSize,
                padding: EdgeInsets.all(badgeSize * 0.1),
                decoration: BoxDecoration(
                  color: NsColors.of(context).surface,
                  shape: BoxShape.circle,
                ),
                child: NsMascot(
                  size: badgeSize * 0.8,
                  mood: NsMascotMood.happy,
                  look: const Offset(0, 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
