import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../models/user_profile.dart';
import '../theme/app_theme.dart';

/// Displays a citizen's profile avatar (local file, remote URL, or default
/// initials/icon) and updates automatically when [UserProfile] changes.
class NsUserAvatar extends StatelessWidget {
  const NsUserAvatar({
    super.key,
    required this.profile,
    this.size = 40,
    this.fallbackInitials,
  });

  final UserProfile? profile;
  final double size;
  final String? fallbackInitials;

  @override
  Widget build(BuildContext context) {
    final tokens = NsColors.of(context);
    final localPath = profile?.localPhotoPath;
    final remoteUrl = profile?.photoUrl;

    Widget? image;
    if (localPath != null &&
        localPath.trim().isNotEmpty &&
        File(localPath).existsSync()) {
      image = Image.file(
        File(localPath),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultContent(tokens),
      );
    } else if (remoteUrl != null && remoteUrl.trim().isNotEmpty) {
      image = Image.network(
        remoteUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _defaultContent(tokens),
      );
    }

    final ringWidth = size >= 64 ? 2.5 : 1.8;
    final gap = size >= 64 ? 2.0 : 1.2;

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ringWidth + gap),
      decoration: BoxDecoration(
        color: tokens.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary, width: ringWidth),
      ),
      child: ClipOval(
        child: Container(
          color: tokens.mint,
          alignment: Alignment.center,
          child: image != null
              ? SizedBox.expand(child: image)
              : _defaultContent(tokens),
        ),
      ),
    );
  }

  Widget _defaultContent(NsColors tokens) {
    final initials = _computeInitials();
    if (initials != null) {
      return Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w900,
            color: tokens.accentText,
            letterSpacing: -0.4,
          ),
        ),
      );
    }
    return Icon(
      Icons.person_rounded,
      size: size * 0.55,
      color: tokens.accentText,
    );
  }

  String? _computeInitials() {
    final name = profile?.displayName.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length == 1) {
        return parts.first.characters.first.toUpperCase();
      }
      return (parts.first.characters.first + parts.last.characters.first)
          .toUpperCase();
    }
    final fallback = fallbackInitials?.trim();
    if (fallback != null && fallback.isNotEmpty && fallback != 'NS') {
      return fallback;
    }
    return null;
  }
}
