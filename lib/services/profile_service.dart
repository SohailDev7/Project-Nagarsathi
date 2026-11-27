import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../utils/validators.dart';
import 'auth_service.dart';

/// Manages the signed-in citizen's profile, local avatar file, home ward,
/// and notification channel preferences.
///
/// Exposes [notifier] so the home screen, avatar button, posts, and comments
/// reflect edits immediately without restarting the app.
class ProfileService {
  ProfileService._();

  static final ProfileService instance = ProfileService._();

  static const _users = 'users';

  final ValueNotifier<UserProfile?> notifier = ValueNotifier<UserProfile?>(null);

  String _uidKey(String base, String uid) => '${base}_$uid';

  String _currentUid() {
    if (AuthService.isConfigured) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && uid.isNotEmpty) return uid;
    }
    return 'local_citizen';
  }

  /// Loads cached preferences + Firestore profile (if configured) and updates
  /// [notifier].
  Future<UserProfile> loadProfile({String? fallbackName}) async {
    final uid = _currentUid();
    final prefs = await _safePrefs();

    var profile = notifier.value?.uid == uid
        ? notifier.value!
        : UserProfile(uid: uid, displayName: fallbackName?.trim() ?? '');

    if (prefs != null) {
      final cachedName = prefs.getString('cached_display_name')?.trim();
      final cachedAvatar = prefs
          .getString(_uidKey('cached_local_avatar', uid))
          ?.trim();
      final cachedWard = prefs.getInt(_uidKey('cached_home_ward', uid));
      final cachedMunicipality = prefs
          .getString(_uidKey('cached_home_municipality', uid))
          ?.trim();
      final cachedChannels = prefs.getStringList(
        _uidKey('cached_notification_channels', uid),
      );

      final validLocalAvatar =
          cachedAvatar != null &&
              cachedAvatar.isNotEmpty &&
              File(cachedAvatar).existsSync()
          ? cachedAvatar
          : null;

      final parsedChannels = <NotificationChannel>{};
      if (cachedChannels != null) {
        for (final key in cachedChannels) {
          final parsed = NotificationChannel.fromKey(key);
          if (parsed != null) parsedChannels.add(parsed);
        }
      }

      profile = profile.copyWith(
        displayName: (cachedName != null && cachedName.isNotEmpty)
            ? cachedName
            : profile.displayName,
        localPhotoPath: validLocalAvatar,
        clearLocalPhotoPath: validLocalAvatar == null,
        homeWard: cachedWard ?? profile.homeWard,
        homeMunicipality:
            (cachedMunicipality != null && cachedMunicipality.isNotEmpty)
            ? cachedMunicipality
            : profile.homeMunicipality,
        notificationChannels: cachedChannels != null
            ? parsedChannels
            : profile.notificationChannels,
      );
    }

    if (AuthService.isConfigured) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (profile.displayName.isEmpty &&
            user.displayName != null &&
            user.displayName!.trim().isNotEmpty) {
          profile = profile.copyWith(displayName: user.displayName!.trim());
        }
        try {
          final doc = await FirebaseFirestore.instance
              .collection(_users)
              .doc(user.uid)
              .get();
          if (doc.exists) {
            final remote = UserProfile.fromMap(user.uid, doc.data());
            profile = profile.copyWith(
              displayName: remote.displayName.isNotEmpty
                  ? remote.displayName
                  : profile.displayName,
              photoUrl: remote.photoUrl,
              homeMunicipality: remote.homeMunicipality,
              homeWard: remote.homeWard ?? profile.homeWard,
              notificationChannels: doc.data()?['notificationChannels'] != null
                  ? remote.notificationChannels
                  : profile.notificationChannels,
            );
          }
        } catch (_) {
          // Keep cached/local profile if offline or rules reject read.
        }
      }
    }

    notifier.value = profile;
    return profile;
  }

  /// Validates and saves a new display name, updating [notifier] immediately.
  Future<UserProfile> updateDisplayName(String rawName) async {
    final error = Validators.displayName(rawName);
    if (error != null) {
      throw ArgumentError(error);
    }
    final cleanName = rawName.trim();
    final current = notifier.value ?? UserProfile(uid: _currentUid());
    final updated = current.copyWith(displayName: cleanName);
    notifier.value = updated;

    final prefs = await _safePrefs();
    await prefs?.setString('cached_display_name', cleanName);

    if (AuthService.isConfigured) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.updateDisplayName(cleanName);
        } catch (_) {}
        await _mergeUserDoc(user.uid, {
          'name': cleanName,
          'displayName': cleanName,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return updated;
  }

  /// Saves the cropped avatar bytes locally and updates [notifier] immediately.
  ///
  /// Swap this implementation with a Cloudinary upload later and store the
  /// returned URL in `photoUrl`.
  Future<UserProfile> saveAvatarBytes(Uint8List croppedBytes) async {
    final uid = _currentUid();
    final current = notifier.value ?? UserProfile(uid: uid);

    final docsDir = await getApplicationDocumentsDirectory();
    final avatarDir = Directory('${docsDir.path}${Platform.pathSeparator}avatars');
    if (!avatarDir.existsSync()) {
      avatarDir.createSync(recursive: true);
    }

    // Use a timestamped filename so Image.file cache refreshes immediately.
    final fileName =
        '${uid}_${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File('${avatarDir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(croppedBytes, flush: true);

    // Clean up previous local avatar file if present.
    final oldPath = current.localPhotoPath;
    if (oldPath != null && oldPath != file.path) {
      try {
        final oldFile = File(oldPath);
        if (oldFile.existsSync()) oldFile.deleteSync();
      } catch (_) {}
    }

    final updated = current.copyWith(
      localPhotoPath: file.path,
      clearPhotoUrl: true,
    );
    notifier.value = updated;

    final prefs = await _safePrefs();
    await prefs?.setString(_uidKey('cached_local_avatar', uid), file.path);

    return updated;
  }

  /// Resets the avatar back to the system default icon/initials.
  Future<UserProfile> resetAvatar() async {
    final uid = _currentUid();
    final current = notifier.value ?? UserProfile(uid: uid);

    final oldPath = current.localPhotoPath;
    if (oldPath != null) {
      try {
        final oldFile = File(oldPath);
        if (oldFile.existsSync()) oldFile.deleteSync();
      } catch (_) {}
    }

    final updated = current.copyWith(
      clearLocalPhotoPath: true,
      clearPhotoUrl: true,
    );
    notifier.value = updated;

    final prefs = await _safePrefs();
    await prefs?.remove(_uidKey('cached_local_avatar', uid));

    if (AuthService.isConfigured) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.updatePhotoURL(null);
        } catch (_) {}
        await _mergeUserDoc(user.uid, {
          'photoUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return updated;
  }

  /// Saves the citizen's home ward and preferred notification channels.
  Future<UserProfile> updatePreferences({
    required int? homeWard,
    String homeMunicipality = 'Kathmandu Metropolitan City',
    required Set<NotificationChannel> notificationChannels,
  }) async {
    final uid = _currentUid();
    final current = notifier.value ?? UserProfile(uid: uid);
    final updated = current.copyWith(
      homeWard: homeWard,
      clearHomeWard: homeWard == null,
      homeMunicipality: homeMunicipality,
      notificationChannels: Set<NotificationChannel>.from(notificationChannels),
    );
    notifier.value = updated;

    final prefs = await _safePrefs();
    if (prefs != null) {
      if (homeWard != null) {
        await prefs.setInt(_uidKey('cached_home_ward', uid), homeWard);
      } else {
        await prefs.remove(_uidKey('cached_home_ward', uid));
      }
      await prefs.setString(
        _uidKey('cached_home_municipality', uid),
        homeMunicipality,
      );
      await prefs.setStringList(
        _uidKey('cached_notification_channels', uid),
        notificationChannels.map((c) => c.key).toList()..sort(),
      );
    }

    if (AuthService.isConfigured) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _mergeUserDoc(user.uid, {
          'homeMunicipality': homeMunicipality,
          'homeWard': ?homeWard,
          'notificationChannels':
              notificationChannels.map((c) => c.key).toList()..sort(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    return updated;
  }

  /// Allows tests to seed a profile directly without disk/Firebase I/O.
  @visibleForTesting
  void setForTest(UserProfile? profile) {
    notifier.value = profile;
  }

  Future<void> _mergeUserDoc(String uid, Map<String, dynamic> fields) async {
    try {
      await FirebaseFirestore.instance.collection(_users).doc(uid).set({
        'uid': uid,
        'role': 'citizen',
        ...fields,
      }, SetOptions(merge: true));
    } catch (_) {
      // Local state and SharedPreferences remain updated even if offline.
    }
  }

  Future<SharedPreferences?> _safePrefs() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }
}
