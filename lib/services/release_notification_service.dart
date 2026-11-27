import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update.dart';
import 'firebase_bootstrap.dart';

/// Handles push and local notifications when a new GitHub release is published.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.initialize();
  if (!ReleaseNotificationService.isReleaseMessage(message.data)) return;

  // Messages that include a `notification` block are displayed natively by FCM
  // while backgrounded; only render locally for data-only push payloads.
  if (message.notification != null) return;

  final copy = ReleaseNotificationService.copyFromRemoteMessage(message);
  await ReleaseNotificationService.instance.showLocalReleaseNotification(
    title: copy.title,
    body: copy.body,
    version: copy.version,
  );
}

class ReleaseNotificationCopy {
  const ReleaseNotificationCopy({
    required this.title,
    required this.body,
    required this.version,
  });

  final String title;
  final String body;
  final String version;
}

class ReleaseNotificationService {
  ReleaseNotificationService._();

  static final ReleaseNotificationService instance =
      ReleaseNotificationService._();

  static const String updatesTopic = 'app_updates';
  static const String channelId = 'app_updates';
  static const String channelName = 'App Updates';
  static const String channelDescription =
      'Notifies you when a new NagarSathi release is published on GitHub.';
  static const String payloadPrefix = 'github_release';

  static const int _notificationId = 4107;
  static const String _lastNotifiedTagKey = 'github_update_last_notified_tag';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _localReady = false;
  bool _topicSubscribed = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedAppSub;

  VoidCallback? _onUpdateNotificationTap;
  Future<void> Function()? _onForegroundReleasePush;

  /// Whether FCM [data] represents a GitHub release update payload.
  static bool isReleaseMessage(Map<String, dynamic> data) {
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    if (type == payloadPrefix) return true;
    final tag = (data['tag'] ?? data['version'] ?? '').toString().trim();
    return tag.isNotEmpty;
  }

  /// Extracts readable notification title/body for a GitHub [AppUpdate].
  static ReleaseNotificationCopy copyFromAppUpdate(AppUpdate update) {
    final versionLabel = update.version.display;
    final summaryLine = update.notes
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^[\s\-#*•]+'), '').trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');

    final body = summaryLine.isNotEmpty
        ? '$summaryLine — Tap to update NagarSathi.'
        : 'A new version is ready on GitHub Releases. Tap to update.';

    return ReleaseNotificationCopy(
      title: 'NagarSathi v$versionLabel is available',
      body: body,
      version: versionLabel,
    );
  }

  /// Extracts notification copy from an incoming FCM [RemoteMessage].
  static ReleaseNotificationCopy copyFromRemoteMessage(RemoteMessage message) {
    final rawVersion =
        (message.data['version'] ?? message.data['tag'] ?? '').toString().trim();
    final version = rawVersion.startsWith(RegExp(r'[vV]'))
        ? rawVersion.substring(1)
        : rawVersion;
    final title = (message.notification?.title ?? '').trim().isNotEmpty
        ? message.notification!.title!.trim()
        : (version.isNotEmpty
            ? 'NagarSathi v$version is available'
            : 'NagarSathi update available');
    final body = (message.notification?.body ?? '').trim().isNotEmpty
        ? message.notification!.body!.trim()
        : ((message.data['notes'] ?? '').toString().trim().isNotEmpty
            ? message.data['notes'].toString().trim()
            : 'Tap to review what\'s new and install the latest release.');

    return ReleaseNotificationCopy(title: title, body: body, version: version);
  }

  /// Initializes local notification channels, Android 13+ permission, and FCM
  /// topic subscription for GitHub release broadcasts.
  Future<void> initialize({
    required VoidCallback onUpdateNotificationTap,
    Future<void> Function()? onForegroundReleasePush,
  }) async {
    _onUpdateNotificationTap = onUpdateNotificationTap;
    _onForegroundReleasePush = onForegroundReleasePush;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (!_initialized) {
      _initialized = true;
      await _initLocalNotifications();
    }

    if (FirebaseBootstrap.isReady && !_topicSubscribed) {
      await _initFirebaseMessaging();
    }
  }

  Future<void> _initLocalNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      final androidPlugin =
          _localNotifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.high,
          ),
        );
        await androidPlugin.requestNotificationsPermission();
      }
      _localReady = true;

      final launchDetails =
          await _localNotifications.getNotificationAppLaunchDetails();
      final response = launchDetails?.notificationResponse;
      if ((launchDetails?.didNotificationLaunchApp ?? false) &&
          response != null &&
          _isUpdatePayload(response.payload)) {
        _onUpdateNotificationTap?.call();
      }
    } catch (error) {
      debugPrint('Local release notifications unavailable: $error');
    }
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      final messaging = FirebaseMessaging.instance;
      await messaging.subscribeToTopic(updatesTopic);
      _topicSubscribed = true;

      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
        if (!isReleaseMessage(message.data) && message.notification == null) {
          return;
        }
        final copy = copyFromRemoteMessage(message);
        if (copy.version.isNotEmpty) {
          await markVersionNotified(copy.version);
        }
        await showLocalReleaseNotification(
          title: copy.title,
          body: copy.body,
          version: copy.version,
        );
        final callback = _onForegroundReleasePush;
        if (callback != null) {
          await callback();
        }
      });

      await _openedAppSub?.cancel();
      _openedAppSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        if (isReleaseMessage(message.data) || message.notification != null) {
          _onUpdateNotificationTap?.call();
        }
      });

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null &&
          (isReleaseMessage(initialMessage.data) ||
              initialMessage.notification != null)) {
        _onUpdateNotificationTap?.call();
      }
    } catch (error) {
      debugPrint('FCM release subscription unavailable: $error');
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (_isUpdatePayload(response.payload)) {
      _onUpdateNotificationTap?.call();
    }
  }

  static bool _isUpdatePayload(String? payload) =>
      payload != null && payload.startsWith(payloadPrefix);

  /// Records [version] as already notified so repeat checks do not spam users.
  Future<void> markVersionNotified(
    String version, {
    Future<SharedPreferences> Function()? prefsLoader,
  }) async {
    final normalized = version.trim();
    if (normalized.isEmpty) return;
    final prefs = await (prefsLoader ?? SharedPreferences.getInstance)();
    await prefs.setString(_lastNotifiedTagKey, normalized);
  }

  /// Sends a local notification once per [update.version] when a new GitHub
  /// release is discovered and was not yet notified locally.
  Future<bool> notifyIfNewRelease(
    AppUpdate update, {
    Future<SharedPreferences> Function()? prefsLoader,
    Future<void> Function(ReleaseNotificationCopy copy)? showNotification,
  }) async {
    final prefs = await (prefsLoader ?? SharedPreferences.getInstance)();
    final versionKey = update.version.display;
    if (prefs.getString(_lastNotifiedTagKey) == versionKey) {
      return false;
    }

    final copy = copyFromAppUpdate(update);
    await prefs.setString(_lastNotifiedTagKey, versionKey);

    if (showNotification != null) {
      await showNotification(copy);
      return true;
    }

    await showLocalReleaseNotification(
      title: copy.title,
      body: copy.body,
      version: copy.version,
    );
    return true;
  }

  /// Displays an Android notification banner for a release update.
  Future<void> showLocalReleaseNotification({
    required String title,
    required String body,
    String version = '',
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_localReady) {
      await _initLocalNotifications();
    }
    if (!_localReady) return;

    try {
      final payload = version.isEmpty ? payloadPrefix : '$payloadPrefix:$version';
      await _localNotifications.show(
        id: _notificationId,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        payload: payload,
      );
    } catch (error) {
      debugPrint('Could not show release notification: $error');
    }
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _openedAppSub?.cancel();
    _foregroundSub = null;
    _openedAppSub = null;
  }
}
