/// Notification delivery channels a citizen can subscribe to in their profile.
enum NotificationChannel {
  push('push', 'Push notifications'),
  sms('sms', 'SMS alerts'),
  email('email', 'Email updates');

  const NotificationChannel(this.key, this.label);

  final String key;
  final String label;

  static NotificationChannel? fromKey(String key) {
    final normalized = key.trim().toLowerCase();
    for (final channel in values) {
      if (channel.key == normalized) return channel;
    }
    return null;
  }
}

/// Citizen profile and notification preferences.
class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName = '',
    this.localPhotoPath,
    this.photoUrl,
    this.homeMunicipality = 'Kathmandu Metropolitan City',
    this.homeWard,
    this.notificationChannels = const {NotificationChannel.push},
  });

  final String uid;
  final String displayName;

  /// Local file path for the cropped avatar (ready to be replaced by a
  /// Cloudinary upload URL later).
  final String? localPhotoPath;

  /// Remote avatar URL (used when Cloudinary upload is wired in later).
  final String? photoUrl;

  final String homeMunicipality;
  final int? homeWard;
  final Set<NotificationChannel> notificationChannels;

  bool get hasCustomAvatar =>
      (localPhotoPath != null && localPhotoPath!.trim().isNotEmpty) ||
      (photoUrl != null && photoUrl!.trim().isNotEmpty);

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? localPhotoPath,
    bool clearLocalPhotoPath = false,
    String? photoUrl,
    bool clearPhotoUrl = false,
    String? homeMunicipality,
    int? homeWard,
    bool clearHomeWard = false,
    Set<NotificationChannel>? notificationChannels,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      localPhotoPath:
          clearLocalPhotoPath ? null : (localPhotoPath ?? this.localPhotoPath),
      photoUrl: clearPhotoUrl ? null : (photoUrl ?? this.photoUrl),
      homeMunicipality: homeMunicipality ?? this.homeMunicipality,
      homeWard: clearHomeWard ? null : (homeWard ?? this.homeWard),
      notificationChannels: notificationChannels ?? this.notificationChannels,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'name': displayName,
      'displayName': displayName,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'homeMunicipality': homeMunicipality,
      if (homeWard != null) 'homeWard': homeWard,
      'notificationChannels':
          notificationChannels.map((c) => c.key).toList()..sort(),
    };
  }

  static UserProfile fromMap(String uid, Map<String, dynamic>? data) {
    if (data == null) return UserProfile(uid: uid);

    final rawName =
        (data['displayName'] as String?) ?? (data['name'] as String?) ?? '';
    final rawPhotoUrl = data['photoUrl'] as String?;

    int? ward;
    final rawHomeWard = data['homeWard'];
    if (rawHomeWard is num) {
      ward = rawHomeWard.toInt();
    } else if (data['location'] is Map &&
        (data['location'] as Map)['ward'] is num) {
      ward = ((data['location'] as Map)['ward'] as num).toInt();
    }

    final municipality =
        (data['homeMunicipality'] as String?) ??
        (data['location'] is Map
            ? (data['location'] as Map)['municipality'] as String?
            : null) ??
        'Kathmandu Metropolitan City';

    final rawChannels = data['notificationChannels'];
    final channels = <NotificationChannel>{};
    if (rawChannels is Iterable) {
      for (final item in rawChannels) {
        if (item is String) {
          final parsed = NotificationChannel.fromKey(item);
          if (parsed != null) channels.add(parsed);
        }
      }
    } else {
      channels.add(NotificationChannel.push);
    }

    return UserProfile(
      uid: uid,
      displayName: rawName.trim(),
      photoUrl: rawPhotoUrl?.trim().isNotEmpty == true
          ? rawPhotoUrl!.trim()
          : null,
      homeMunicipality: municipality.trim().isEmpty
          ? 'Kathmandu Metropolitan City'
          : municipality.trim(),
      homeWard: ward,
      notificationChannels: channels,
    );
  }
}
