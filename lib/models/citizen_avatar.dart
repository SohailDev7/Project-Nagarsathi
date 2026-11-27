import 'package:material_ui/material_ui.dart';

/// The avatar colours a citizen can choose instead of a photo.
///
/// The chosen key is stored on the profile as `avatarColor`, so it follows the
/// citizen across devices.
enum CitizenAvatarColor {
  forest('forest', Color(0xFF14472A), Color(0xFFEAF7E2)),
  lime('lime', Color(0xFF6AD90E), Color(0xFF102B06)),
  teal('teal', Color(0xFF0F7B6C), Color(0xFFE7FFF7)),
  sky('sky', Color(0xFF2B7FD4), Color(0xFFF1F8FF)),
  sun('sun', Color(0xFFE9A11B), Color(0xFF2C1B00)),
  rose('rose', Color(0xFFC2405A), Color(0xFFFFEFF2)),
  plum('plum', Color(0xFF6B3FA0), Color(0xFFF7EEFF)),
  slate('slate', Color(0xFF44515E), Color(0xFFF2F6FA));

  const CitizenAvatarColor(this.key, this.background, this.foreground);

  /// Stable value written to Firestore.
  final String key;

  final Color background;
  final Color foreground;

  static const fallback = CitizenAvatarColor.forest;

  /// Reads a stored key, falling back to the default for unknown values.
  static CitizenAvatarColor fromKey(Object? value) {
    if (value is! String) return fallback;
    final key = value.trim().toLowerCase();
    for (final color in values) {
      if (color.key == key) return color;
    }
    return fallback;
  }
}
