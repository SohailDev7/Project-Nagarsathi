import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/language_controller.dart';
import '../models/data_export_request.dart';
import 'auth_service.dart';

/// Authenticated identity snapshot used when initiating a data export.
class DataExportUserContext {
  const DataExportUserContext({
    required this.uid,
    required this.email,
    this.idToken,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? idToken;
  final String? displayName;
}

/// Requests encrypted personal data export packages (JSON + PDF) delivered via
/// email with an automatic 48-hour expiration window.
class DataExportService {
  DataExportService({
    this._client,
    String? workerUrl,
    this._userContextLoader,
  }) : _workerUrl = workerUrl ?? _defaultWorkerUrl;

  static const _defaultWorkerUrl = String.fromEnvironment(
    'OTP_WORKER_URL',
    defaultValue: 'https://nagarsathi-otp.sohailk2064.workers.dev',
  );
  static const _latestExportPrefsPrefix = 'latest_data_export_';
  static const _latestExportFallbackKey = 'latest_data_export_last';

  final http.Client? _client;
  final String _workerUrl;
  final Future<DataExportUserContext?> Function()? _userContextLoader;

  Future<DataExportUserContext?> resolveUserContext() async {
    if (_userContextLoader != null) {
      return _userContextLoader();
    }
    if (!AuthService.isConfigured) {
      return null;
    }

    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {
      user = null;
    }
    if (user == null) return null;

    var email = user.email?.trim() ?? '';
    var displayName = user.displayName?.trim();

    if (email.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        email = (prefs.getString('cached_email') ?? '').trim();
        displayName ??= prefs.getString('cached_display_name')?.trim();
      } catch (_) {}
    }

    if (email.isEmpty || displayName == null || displayName.isEmpty) {
      for (final collection in const <String>['users', 'staff']) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection(collection)
              .doc(user.uid)
              .get();
          final data = doc.data();
          if (data == null) continue;
          if (email.isEmpty) {
            final docEmail = data['email']?.toString().trim() ?? '';
            if (docEmail.isNotEmpty) email = docEmail;
          }
          if (displayName == null || displayName.isEmpty) {
            final docName = data['name']?.toString().trim() ?? '';
            if (docName.isNotEmpty) displayName = docName;
          }
          if (email.isNotEmpty &&
              displayName != null &&
              displayName.isNotEmpty) {
            break;
          }
        } catch (_) {}
      }
    }

    String? idToken;
    try {
      idToken = await user.getIdToken();
    } catch (_) {}

    return DataExportUserContext(
      uid: user.uid,
      email: email.toLowerCase(),
      idToken: idToken,
      displayName: displayName,
    );
  }

  /// Resolves the signed-in user's registered email if available.
  Future<String?> resolveRegisteredEmail() async {
    final user = await resolveUserContext();
    if (user == null || user.email.trim().isEmpty) return null;
    return user.email.trim();
  }

  /// Initiates a personal data export package request on the backend.
  Future<DataExportRequest> requestExport({String? locale}) async {
    final user = await resolveUserContext();
    if (user == null) {
      throw const DataExportFailure(
        'Sign in to your account to download your data.',
      );
    }
    if (user.email.trim().isEmpty || !user.email.contains('@')) {
      throw const DataExportFailure(
        'A registered email address is required to receive your export link.',
      );
    }
    final token = user.idToken;
    if (token == null || token.trim().isEmpty) {
      throw const DataExportFailure(
        'Could not verify your active session. Sign in again and retry.',
      );
    }

    final client = _client ?? http.Client();
    final ownsClient = _client == null;
    try {
      final response = await client
          .post(
            Uri.parse('$_workerUrl/request-data-export'),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(<String, Object?>{
              'locale': locale ?? LanguageController.instance.value.code,
            }),
          )
          .timeout(const Duration(seconds: 25));

      // The worker answers in JSON, but a proxy or a platform-level failure can
      // still return HTML. Never let that surface as "unexpected response".
      Map<String, dynamic> payload = const <String, dynamic>{};
      final rawBody = response.body.trim();
      if (rawBody.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawBody);
          if (decoded is Map<String, dynamic>) {
            payload = decoded;
          } else if (decoded is Map) {
            payload = Map<String, dynamic>.from(decoded);
          }
        } on FormatException {
          payload = const <String, dynamic>{};
        }
      }

      if (response.statusCode != 200 && response.statusCode != 202) {
        if (response.statusCode == 404) {
          throw const DataExportFailure(
            'Data export service is not available on the server yet.',
          );
        }
        final serverError = payload['error'];
        if (serverError is String && serverError.trim().isNotEmpty) {
          throw DataExportFailure(serverError);
        }
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const DataExportFailure(
            'Your session expired. Sign in again and retry.',
          );
        }
        if (response.statusCode == 429) {
          throw const DataExportFailure(
            'Too many export requests. Please try again later.',
          );
        }
        throw DataExportFailure(
          'The export service is temporarily unavailable '
          '(HTTP ${response.statusCode}). Please try again.',
        );
      }

      if (payload.isEmpty) {
        throw const DataExportFailure(
          'The export service sent an empty response. Please try again.',
        );
      }

      final now = DateTime.now();
      final exportRequest = DataExportRequest(
        exportId: (payload['exportId'] ?? '').toString().isNotEmpty
            ? payload['exportId'].toString()
            : 'exp_${now.millisecondsSinceEpoch}',
        userId: user.uid,
        email: (payload['email'] ?? user.email).toString(),
        status: DataExportStatus.fromWire(payload['status']?.toString()),
        requestedAt: _fromEpoch(payload['requestedAt']) ?? now,
        expiresAt:
            _fromEpoch(payload['expiresAt']) ??
            now.add(DataExportRequest.linkValidity),
        deliveredAt: _fromEpoch(payload['deliveredAt']),
        formats: payload['formats'] is List
            ? (payload['formats'] as List)
                  .map((e) => e.toString())
                  .toList(growable: false)
            : const <String>['json', 'pdf'],
        reportCount: _asInt(payload['reportCount']) ?? 0,
        commentCount: _asInt(payload['commentCount']) ?? 0,
        deliverySlaMinutes: _asInt(payload['deliverySlaMinutes']) ?? 15,
      );

      await _persistLatestExport(exportRequest);
      return exportRequest;
    } on DataExportFailure {
      rethrow;
    } on TimeoutException {
      throw const DataExportFailure(
        'The export request timed out. Check your connection and try again.',
      );
    } catch (_) {
      throw const DataExportFailure(
        'Could not reach the data export service. Check your connection.',
      );
    } finally {
      if (ownsClient) {
        client.close();
      }
    }
  }

  /// Loads the latest export request from local storage (and Firestore if empty).
  Future<DataExportRequest?> loadLatestExport() async {
    final user = await resolveUserContext();
    final prefsKey = user != null
        ? '$_latestExportPrefsPrefix${user.uid}'
        : _latestExportFallbackKey;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(prefsKey);
      if (raw != null && raw.trim().isNotEmpty) {
        final parsed = DataExportRequest.fromJson(raw);
        return parsed.isExpiredAt()
            ? parsed.copyWith(status: DataExportStatus.expired)
            : parsed;
      }
    } catch (_) {}

    if (user != null && AuthService.isConfigured) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('data_exports')
            .orderBy('requestedAt', descending: true)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final parsed = DataExportRequest.fromMap(snap.docs.first.data());
          await _cacheLocally(parsed);
          return parsed.isExpiredAt()
              ? parsed.copyWith(status: DataExportStatus.expired)
              : parsed;
        }
      } catch (_) {}
    }

    return null;
  }

  Future<void> _persistLatestExport(DataExportRequest request) async {
    await _cacheLocally(request);

    if (AuthService.isConfigured && request.userId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(request.userId)
            .collection('data_exports')
            .doc(request.exportId)
            .set(request.toMap());
      } catch (_) {
        // Best-effort Firestore mirror; D1 holds the authoritative export record.
      }
    }
  }

  Future<void> _cacheLocally(DataExportRequest request) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = request.userId.isNotEmpty
          ? '$_latestExportPrefsPrefix${request.userId}'
          : _latestExportFallbackKey;
      await prefs.setString(key, request.toJson());
    } catch (_) {}
  }

  static DateTime? _fromEpoch(Object? value) {
    final ms = _asInt(value);
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
